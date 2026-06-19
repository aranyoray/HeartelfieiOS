import Foundation
import HECore

#if canImport(FoundationNetworking)
import FoundationNetworking  // URLSession async on non-Darwin platforms
#endif

/// Live cloud `ModelClient`. Talks to `HeartelfieConfig.CloudAPI` over
/// `URLSession` with TLS certificate pinning, an offline retry queue, and
/// exponential backoff.
///
/// When `HeartelfieConfig.CloudAPI.useMockResponses` is `true` (the default, so
/// the whole app demos OFFLINE), every call short-circuits the network and
/// returns a realistic, deterministic-but-varied mock immediately — including the
/// proper model attribution strings.
///
/// - Important: The real endpoints, SPKI pins, and request encoding are all
///   placeholders. Each integration seam is marked `// TODO:`.
public final class CloudModelClient: ModelClient {

    private let session: URLSession
    private let queue: RequestQueue
    private let useMocks: Bool
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// - Parameters:
    ///   - useMockResponses: Defaults to `HeartelfieConfig.CloudAPI.useMockResponses`.
    ///   - session: Inject a custom session for testing; otherwise a pinned
    ///     session is built from `pinningDelegate`.
    public init(useMockResponses: Bool = HeartelfieConfig.CloudAPI.useMockResponses,
                session: URLSession? = nil,
                retryPolicy: RetryPolicy = .default) {
        self.useMocks = useMockResponses
        self.queue = RequestQueue(policy: retryPolicy)
        if let session {
            self.session = session
        } else {
            // Pinned session: the delegate enforces certificate pinning.
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = false
            config.timeoutIntervalForRequest = 20
            self.session = URLSession(
                configuration: config,
                delegate: CertificatePinningDelegate(pinsBase64: HeartelfieConfig.CloudAPI.certificatePinsBase64),
                delegateQueue: nil
            )
        }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = dec
        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = enc
    }

    // MARK: - ModelClient

    public func analyzeECG(_ request: ECGAnalysisRequest) async throws -> ECGAnalysisResponse {
        guard !request.samples.isEmpty else { throw ModelClientError.invalidRequest }
        if useMocks {
            return MockResponses.ecg(for: request)
        }
        let url = HeartelfieConfig.CloudAPI.baseURL.appendingPathComponent(HeartelfieConfig.CloudAPI.ecgAnalysisPath)
        return try await send(request, to: url)
    }

    public func encodePPG(_ request: PPGEncodeRequest) async throws -> PPGEncodeResponse {
        guard request.channels.values.contains(where: { !$0.isEmpty }) else {
            throw ModelClientError.invalidRequest
        }
        if useMocks {
            return MockResponses.ppg(for: request)
        }
        let url = HeartelfieConfig.CloudAPI.baseURL.appendingPathComponent(HeartelfieConfig.CloudAPI.ppgEncodePath)
        return try await send(request, to: url)
    }

    // MARK: - Networking (real path; only reached when mocks are off)

    /// Encode `body`, POST it through the retry queue, and decode the response.
    private func send<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        _ body: Req,
        to url: URL
    ) async throws -> Res {
        // TODO: Add auth headers (API key / signed request) for production.
        let payload = try encoder.encode(body)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = payload

        let session = self.session
        let data = try await queue.perform {
            try await Self.performOnce(urlRequest, session: session)
        }
        do {
            return try decoder.decode(Res.self, from: data)
        } catch {
            throw ModelClientError.decodingFailed
        }
    }

    /// One network attempt. Throws so the queue can decide whether to retry.
    private static func performOnce(_ request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError where Self.isOffline(urlError) {
            throw ModelClientError.offlineQueued
        }
        guard let http = response as? HTTPURLResponse else {
            throw ModelClientError.httpStatus(-1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ModelClientError.httpStatus(http.statusCode)
        }
        return data
    }

    private static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost,
             .dataNotAllowed, .cannotConnectToHost, .timedOut:
            return true
        default:
            return false
        }
    }
}

// MARK: - Retry policy

/// Exponential-backoff retry policy for the offline queue.
public struct RetryPolicy: Sendable, Hashable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let multiplier: Double
    public let maxDelay: TimeInterval

    public init(maxAttempts: Int = 4,
                baseDelay: TimeInterval = 0.5,
                multiplier: Double = 2.0,
                maxDelay: TimeInterval = 8.0) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = baseDelay
        self.multiplier = multiplier
        self.maxDelay = maxDelay
    }

    public static let `default` = RetryPolicy()

    /// Backoff delay (seconds) before the given 1-based attempt index.
    func delay(forAttempt attempt: Int) -> TimeInterval {
        let exp = pow(multiplier, Double(max(0, attempt - 1)))
        return min(baseDelay * exp, maxDelay)
    }
}

// MARK: - Offline request queue

/// Serial offline-aware request queue. Retries transient failures with
/// exponential backoff and, when the device is offline, enqueues the work so a
/// `pending` state can be surfaced to callers.
///
/// Modelled as an `actor` so concurrent callers can't race the pending count.
public actor RequestQueue {

    private let policy: RetryPolicy
    /// Number of requests currently parked awaiting connectivity/retry.
    private(set) public var pendingCount = 0

    public init(policy: RetryPolicy = .default) {
        self.policy = policy
    }

    /// `true` while one or more requests are awaiting retry — drives a UI
    /// "pending — will retry when back online" affordance.
    public var hasPending: Bool { pendingCount > 0 }

    /// Run `operation`, retrying transient/offline failures with exponential
    /// backoff up to the policy's attempt budget.
    public func perform(_ operation: @Sendable () async throws -> Data) async throws -> Data {
        var lastError: Error = ModelClientError.retriesExhausted
        for attempt in 1...policy.maxAttempts {
            do {
                let result = try await operation()
                return result
            } catch let error {
                lastError = error
                guard Self.isRetryable(error), attempt < policy.maxAttempts else { break }
                // Mark pending while we back off (especially for offline).
                pendingCount += 1
                defer { pendingCount = max(0, pendingCount - 1) }
                let seconds = policy.delay(forAttempt: attempt)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
        throw lastError
    }

    private static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case ModelClientError.offlineQueued:
            return true
        case ModelClientError.httpStatus(let code):
            return code >= 500 || code == 429 || code == -1
        default:
            return false
        }
    }
}

// MARK: - TLS certificate pinning

/// `URLSessionDelegate` that enforces TLS certificate pinning against the
/// configured SPKI SHA-256 pins.
///
/// - Important: The actual SPKI extraction + SHA-256 hashing is left as a clearly
///   marked TODO so production can wire it with `SecCertificateCopyKey` /
///   `SecKeyCopyExternalRepresentation` + the ASN.1 SPKI header, hashed with
///   CryptoKit's `SHA256`. Until real pins (not the placeholder) are configured,
///   the delegate performs default trust evaluation so the app still runs.
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    // `@unchecked Sendable`: derives from `NSObject` (non-Sendable) but is
    // genuinely immutable — its only stored property is an immutable `[String]`.
    private let pinsBase64: [String]

    public init(pinsBase64: [String]) {
        self.pinsBase64 = pinsBase64
    }

    /// `true` once real (non-placeholder) pins are configured.
    private var hasRealPins: Bool {
        pinsBase64.contains { !$0.isEmpty && !$0.hasPrefix("REPLACE_WITH_REAL") }
    }

    #if canImport(Security)
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // No real pins configured yet → fall back to system trust so the app runs.
        guard hasRealPins else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // TODO: Real pinning. For each cert in the chain:
        //   1. let key = SecCertificateCopyKey(cert)
        //   2. let der = SecKeyCopyExternalRepresentation(key, &error)
        //   3. prepend the ASN.1 SPKI header for the key type
        //   4. let pin = Data(SHA256.hash(data: spki)).base64EncodedString()
        //   5. accept iff `pinsBase64.contains(pin)`.
        // Until that is implemented, evaluate default trust and reject on failure.
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    #endif
}

// MARK: - Realistic offline mocks

/// Deterministic-but-varied mock responses so Heartelfie demos fully offline.
///
/// Values are plausible for a healthy adult and vary slightly with skin tone and
/// signal statistics so repeated demos don't look frozen. The skin-tone variation
/// is deliberately *tiny* and is for demo realism only — it is NOT a clinical
/// correction. Real deployments must use validated, bias-audited models.
enum MockResponses {

    // ECG-FM attribution (placeholders — real model names).
    static let ecgModelName = "ECG-FM"
    static let ecgModelVersion = "0.1-mock"
    static let ecgAttribution = "ECG-FM (reduced-lead finetune) — mock response. Real deployment must honor the model's data-license attribution."

    // PaPaGei / Pulse-PPG attribution (placeholders — real model names).
    static let ppgModelName = "PaPaGei-PPG"
    static let ppgModelVersion = "0.3-mock"
    static let ppgAttribution = "PaPaGei / Pulse-PPG encoder — mock response. Real deployment must honor the model's data-license attribution."

    /// Stable pseudo-random value in `0...1` derived from a buffer + seed, so the
    /// same input always yields the same mock (deterministic) yet different inputs
    /// vary (realistic). No RNG state, fully `Sendable`.
    static func jitter(_ samples: [Double], seed: Int) -> Double {
        var hash = UInt64(bitPattern: Int64(seed &* 2_654_435_761))
        let stride = max(1, samples.count / 64)
        var i = 0
        while i < samples.count {
            let bits = samples[i].isFinite ? samples[i].bitPattern : 0
            hash = (hash ^ bits) &* 1_099_511_628_211
            i += stride
        }
        hash ^= UInt64(samples.count) &* 14_695_981_039_346_656_037
        // Map high bits to 0...1.
        return Double(hash >> 11) / Double(1 << 53)
    }

    static func ecg(for request: ECGAnalysisRequest) -> ECGAnalysisResponse {
        let j = jitter(request.samples, seed: 11)
        // Resting sinus heart rate ~62–78 bpm.
        let heartRate = (62 + j * 16).rounded()
        // Sinus rhythm with a tiny irregularity ~1.5–3%.
        let irregularity = (1.5 + j * 1.5)
        // High confidence for a clean device lead ~0.9–0.97.
        let confidence = 0.90 + j * 0.07
        return ECGAnalysisResponse(
            heartRate: heartRate,
            rhythmLabel: "Sinus rhythm",
            irregularityPercent: irregularity,
            confidence: confidence,
            modelName: ecgModelName,
            modelVersion: ecgModelVersion,
            attribution: ecgAttribution
        )
    }

    static func ppg(for request: PPGEncodeRequest) -> PPGEncodeResponse {
        // Use a representative channel (prefer infrared/red) for the jitter seed.
        let buffer = request.channels["infrared"]
            ?? request.channels["red"]
            ?? request.channels.values.first
            ?? []
        let j = jitter(buffer, seed: 23)

        // Hemoglobin ~13.5 g/dL nominal with small spread (±0.6).
        var hemoglobin = 13.5 + (j - 0.5) * 1.2
        // Tiny, DEMO-ONLY skin-tone variation (NOT a clinical correction): optical
        // Hb estimation is harder at higher melanin, so we nudge the mock a hair to
        // look realistic. Real models must be bias-audited; this is cosmetic only.
        if let mst = request.skinTone {
            hemoglobin += (Double(mst) - 5.0) * 0.02   // ≤ ±0.1 g/dL across MST 1–10
        }
        hemoglobin = (hemoglobin * 10).rounded() / 10   // 1 dp

        // Clinical SpO₂ ~97–99%.
        let spo2 = (97 + j * 2).rounded()
        // Anemia risk ~6–10%.
        let anemiaRisk = (6 + j * 4).rounded()
        // Perfusion index ~2.0–2.8%.
        let perfusion = ((2.0 + j * 0.8) * 10).rounded() / 10
        // Confidence ~0.85–0.94, slightly lower at MST extremes (demo realism).
        var confidence = 0.85 + j * 0.09
        if let mst = request.skinTone { confidence -= abs(Double(mst) - 5.0) * 0.005 }

        return PPGEncodeResponse(
            hemoglobin: hemoglobin,
            anemiaRiskPercent: anemiaRisk,
            spo2: spo2,
            perfusionIndex: perfusion,
            confidence: min(max(confidence, 0), 1),
            modelName: ppgModelName,
            modelVersion: ppgModelVersion,
            attribution: ppgAttribution
        )
    }
}
