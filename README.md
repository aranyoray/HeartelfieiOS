# Heartelfie

A premium, production-grade iOS app for **daily cardiovascular wellness
self-checks**, plus a companion **web wellness atlas** (see [`Web/`](Web/)).

Heartelfie is the companion app for the **Heartelfie hardware device** (a
multi-wavelength finger-clip biosensor with heart-rhythm and bio-impedance
sensing) *and* offers phone-only wellness screening when the device isn't
connected.

> **Heartelfie offers wellness and screening insights. It is not a medical
> device and does not diagnose, treat, cure, or prevent any medical condition.**
> If you think you're having a cardiac event, call your local emergency services
> right away — do not rely on this app.

> **App Store framing.** Every user-facing metric is intentionally
> **wellness-framed** and non-diagnostic. Clinical/measurement terms
> (blood pressure, hemoglobin, SpO₂, ECG…) are never shown as claims — see
> [App Store compliance & wellness framing](#app-store-compliance--wellness-framing).

---

## The one idea behind the architecture: be honest about every signal

Every reading in Heartelfie carries, end-to-end, **where it came from** and **how
much to trust it**. This is enforced in the type system, not just the UI.

### Two explicit tiers (`MeasurementTier`)

| Tier | Source | Meaning |
|------|--------|---------|
| **Screening** | The phone's own sensors (camera, mic, motion) | Wellness-grade, lower confidence — *"not a medical measurement."* |
| **Measurement** | The connected Heartelfie hardware device (BLE) | Higher-accuracy, clinical-grade path. |

**A smartphone has no rhythm-sensing electrode.** The higher-confidence
device-only signals (surfaced under wellness labels — *Heart Rhythm*, *Oxygen
Wellness*, *Oxygen-Carry Wellness*) come *only* from the Heartelfie hardware. The
phone produces wellness screening signals only (camera→PPG/rPPG,
accelerometer→SCG, mic→PCG). `MetricKind.isDeviceOnly` makes it impossible for a
phone modality to surface a device-only metric, and a unit test
(`HECoreTests.testPhoneModalitiesNeverExposeDeviceOnlyMetrics`) guards it.

### Every reading is self-describing (`CardioReading`)

A reading always carries its `tier`, a `Confidence` (0–1 + band), the
`SignalQuality` (SQI), full model `Provenance` (engine + name + version +
attribution), a softened `RiskLevel`, and a plain-language **non-diagnostic**
interpretation.

### Signal-quality gating is mandatory

Every capture passes a **Signal Quality Index** check *before* any metric is
computed (`SQIClassifier`). Poor captures are rejected with **specific,
actionable** coaching ("hold still," "increase lighting," "reposition finger") —
a metric is never computed from a rejected signal.

### Skin-tone equity is a first-class feature

Onboarding optionally captures a **Monk Skin Tone (1–10)** self-selection, which
is passed into the processing/ML layer (optical PPG behaves differently across
melanin levels) and whose use is disclosed to the user. The palette is
colorblind-safe and imagery is inclusive.

---

## Modules (Swift Package Manager)

The library layer is a single local Swift package (`./Package.swift`) with seven
modules; the thin app target lives in `App/Heartelfie`.

```
HECore        Domain & contracts: tiers, modalities, metrics, readings, SQI,
              confidence, provenance, risk, MonkSkinTone, ClinicalConfig
              (centralized placeholder ranges), HeartelfieConfig (branding +
              cloud + BLE placeholders), disclaimers. No UI, no I/O.

HEDesign      Design system: programmatic light/dark tokens (color, type,
              spacing, radius, shadow) + premium SwiftUI components (score ring,
              live waveform, metric card, tier badge, confidence meter, SQI
              coach, device chip, state views, Monk swatch…). Depends on HECore.

HESignal      DSP: vDSP-backed bandpass biquad filters, peak detection, HR/HRV
              (SDNN/RMSSD), autocorrelation-based SQI gate, and a SignalProcessor
              that scopes metrics to each modality. Seedable synthetic PPG/ECG
              generators. Depends on HECore.

HESensors     Protocol-oriented sensor layer: CameraPPG / FaceRPPG / MotionSCG /
              MicPCG / HeartelfieDevice sensors, each with a Mock variant + a
              BLE manager and simulated peripheral. Depends on HECore, HESignal.

HEML          On-device CoreML wrappers (with stub fallbacks) + a cloud model
              client (ECG-FM, PaPaGei/Pulse-PPG) with offline queue, retry, TLS
              pinning hook, and realistic mock responses. Depends on HECore,
              HESignal.

HEPersistence Encrypted local store (AES-GCM + Keychain), HealthKit read/write
              bridge, trends/streak aggregation, and PDF/CSV export. Depends on
              HECore.

HEFeatures    Screens, view models, navigation, and the capture pipeline that
              wires everything together. Depends on all of the above.
```

Dependency direction is strictly downward; `HECore` depends on nothing.

---

## The capture pipeline

```
acquire (CardioSensor → AsyncStream<SignalFrame>)
   → SQI gate (SQIClassifier — rejects here, with coaching)
   → filter (BandpassFilter)
   → feature-extract (PeakDetector, RRMetrics)
   → infer (HESignal on-device + HEML on-device/cloud)
   → CardioReading (metrics, confidence, tier, provenance, SQI, interpretation)
```

When a **device** measurement's confidence is low, the result screen offers a
recheck and a "retake when rested" pathway.

On **clinical (device measurement) results and any elevated reading**, a
`CareAccessCard` surfaces non-diagnostic tips plus **immediate care links** — a
no reading-driven emergency-call or hospital-finder
search (`maps.apple.com`) — escalating to "get care now" framing when a reading
is elevated. Phone numbers and the map query are placeholders in
`HeartelfieConfig.Care` (localize per region — emergency numbers vary by
country).

---

## Running it

### Library + DSP tests (no app project needed)
Open `Package.swift` in Xcode and run the tests, or:
```bash
swift test            # on macOS; runs HECoreTests + HESignalTests
```

### The app
```bash
brew install xcodegen     # once
xcodegen generate         # reads project.yml → Heartelfie.xcodeproj
open Heartelfie.xcodeproj
```
- **Simulator:** runs fully with **no hardware** — all sensors fall back to mocks
  and the device is simulated. The camera PPG is the one path that needs a
  **physical device** (the Simulator has no camera).
- A developer **"Simulate device"** toggle (Profile → Developer, and on the
  pairing screen) forces the mock Heartelfie peripheral so the measurement tier
  is fully demoable offline.

---

## Where to drop in real integrations

Everything replaceable is a clearly-labeled placeholder.

| What | Where |
|------|-------|
| **Clinical reference ranges / thresholds** | `Sources/HECore/ClinicalConfig.swift` — the single source of truth. Nothing else hard-codes a medical threshold. |
| **Product naming, cloud endpoints, BLE UUIDs** | `Sources/HECore/HeartelfieConfig.swift` — one file. |
| **Real CoreML weights** (SQI / HR / rhythm screen) | `Sources/HEML/OnDeviceModels.swift` — marked `// MARK: - Drop real weights here`. Add the `.mlpackage`, load via `MLModel`, replace the heuristic fallback. |
| **Cloud model API** (ECG-FM, PaPaGei/Pulse-PPG) | `Sources/HEML/CloudModelClient.swift` — flip `HeartelfieConfig.CloudAPI.useMockResponses` to `false`, set the base URL + real cert pins. |
| **Real BLE GATT profile** | `Sources/HESensors/HeartelfieBLEManager.swift`, using the UUIDs in `HeartelfieConfig.BLE`. |
| **Sample/replay waveforms** | Synthetic generators in `Sources/HESignal/SyntheticSignal.swift`; bundle real recordings to replay later. |

> **Model provenance & attribution:** cloud-derived results always display model
> name + version + attribution. The mock responses use the real research model
> names (ECG-FM, PaPaGei/Pulse-PPG) precisely because production deployments must
> honor those models' data-license attribution obligations.

---

## Privacy & security

- **On-device first.** Health data is stored in an AES-GCM-encrypted local store
  with the key held in the Keychain (`HEPersistence`). Minimal PII.
- **HealthKit bridge** reads HR, HRV, resting HR, oxygen-saturation, respiratory
  rate, and (optionally, as a supplementary source) Apple Watch heart-rhythm data
  from Apple Health; writes the HealthKit-supported sample types. Custom waveforms
  and device wellness estimates stay only in the encrypted store.
- **Transport:** TLS with a certificate-pinning hook for the cloud API.
- **User control:** full export (PDF/CSV) and full delete.

This is built as a **wellness / screening** app; the architecture is ready to
gate clinical features behind future SaMD clearance. No diagnostic claims are
made anywhere.

---

## App Store compliance & wellness framing

Heartelfie is positioned as a **wellness** app, not a medical device. To keep it
reviewable on consumer app stores, clinically-restricted or diagnostic terms are
**never surfaced to the user as claims** — they are replaced end-to-end with
wellness-framed labels. Internal type/`rawValue` identifiers are unchanged (so
persistence, ML routing, and device gating still work); only the user-facing
copy is reframed.

| Restricted / measurement term | Heartelfie wellness label |
|-------------------------------|---------------------------|
| High blood pressure / hypertension (atlas) | **Circulatory Strain** |
| Coronary heart disease (atlas) | **Heart Health** |
| Stroke (atlas) | **Brain Circulation** |
| Hemoglobin | **Oxygen-Carry Wellness** |
| Anemia risk | **Iron-Level Wellness** |
| SpO₂ / blood oxygen | **Oxygen Wellness** |
| ECG / electrocardiogram | **Heart Rhythm** / **Heart-Rhythm Insight** |
| Rhythm irregularity | **Rhythm Variation** |

Additional guardrails:

- **Non-diagnostic disclaimers everywhere** — `Disclaimers.notMedicalDevice` and
  `Disclaimers.notDiagnostic` are surfaced at onboarding (consent gate), on every
  result/detail screen (`NonDiagnosticFooter`), and in About. The user must
  affirmatively accept before using the app.
- **Persistent emergency notice** (`Disclaimers.emergency`) directing users to
  emergency services for suspected cardiac events.
- **Device-only metrics are hardware-gated** at the type level; the phone never
  claims a device-only wellness signal.
- Before submission, set a real **support / privacy / terms** URL (the `Web/`
  companion hosts `/support`, `/privacy`, `/terms`) and a monitored support
  email (placeholder: `support@heartelfie.app`).

---

## Web companion — Heartelfie Wellness Atlas (`Web/`)

The [`Web/`](Web/) folder is the Heartelfie **web companion**: an interactive 3D
atlas of U.S. county- and state-level **heart & circulatory wellness awareness**,
built from public CDC PLACES community-health estimates (React + TypeScript +
Vite + deck.gl). It was rebranded and reframed to the same wellness vocabulary
as the iOS app.

Because it is a **static web app** (a different stack from this native Swift
package), it is co-located rather than code-merged — the two ship from one repo
and share one brand, disclaimer voice, and terminology. The web app also provides
the **`/privacy`, `/support`, and `/terms` pages** an App Store / Play Store
submission links to for review.

```bash
cd Web
npm install
npm run dev        # http://localhost:5173
npm run build      # tsc + vite build + route prerender
```

All atlas figures describe **geographic areas, never individuals**, and the
shipped dataset is a clearly-badged synthetic placeholder until real CDC data is
loaded (`npm run data:scrape`). See [`Web/README.md`](Web/README.md).

---

## Tech

Swift 6 (strict concurrency), SwiftUI (iOS 17+), async/await + actors +
`AsyncStream`, CoreBluetooth, AVFoundation + Vision, CoreMotion, AVAudioEngine,
Accelerate/vDSP, CoreML, Swift Charts, HealthKit, CryptoKit + Keychain. MVVM with
a lightweight coordinator.
