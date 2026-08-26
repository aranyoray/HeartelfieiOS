# DailyDil

A production-grade iOS app for **daily cardiovascular wellness self-checks**
using only the phone's cameras, plus a companion **web wellness atlas** (see
[`Web/`](Web/)). Formerly named *Heartelfie*; the bundle identifier
(`com.heartelfie.ios`) and on-disk/Keychain identifiers intentionally keep the
old name so existing installs keep their data.

> **DailyDil offers wellness and screening insights. It is not a medical
> device and does not diagnose, treat, cure, or prevent any medical
> condition.** If you think you're having a cardiac event, call your local
> emergency services right away — do not rely on this app.

> **App Store framing.** Every user-facing metric is intentionally
> **wellness-framed** and non-diagnostic. The app contains no hardware/BLE
> path: capture is limited to phone-camera screening (fingertip PPG with the
> rear camera + torch, facial rPPG with the front camera).

---

## The one idea behind the architecture: be honest about every signal

Every reading carries, end-to-end, **where it came from** and **how much to
trust it** — enforced in the type system, not just the UI.

- `MeasurementTier.screening` — phone-camera signals; wellness-grade, lower
  confidence. This is the only tier new readings can have.
- `MeasurementTier.measurement` — retained **only** so readings recorded by
  the retired hardware-device path still decode and render; nothing can
  produce it anymore. The same applies to `MetricKind.isDeviceOnly` metrics.
- Skin-tone equity is a first-class feature: onboarding optionally captures a
  Monk Skin Tone (1–10) self-selection that is passed into the processing
  layer and disclosed to the user.

## Modules (Swift Package Manager)

The library layer is a single local package (`./Package.swift`); a thin app
target lives in `App/Heartelfie` (folder name kept for project stability).

| Module | Purpose |
|--------|---------|
| `HECore` | Domain & contracts: tiers, modalities, metrics, readings, SQI, confidence, provenance, risk, MonkSkinTone, `ClinicalConfig`, branding config, disclaimers. No UI, no I/O. |
| `HEDesign` | Design system: light/dark tokens + SwiftUI components (score ring, live waveform, metric card, tier badge, confidence meter, SQI coach…). |
| `HESignal` | DSP: vDSP-backed bandpass filtering (zero-phase, edge-padded), peak detection, HR/HRV (SDNN/RMSSD), autocorrelation SQI gate. Seedable synthetic PPG generators. |
| `HESensors` | Camera sensors: `CameraPPGSensor` (rear camera + torch fingertip PPG) and `FaceRPPGSensor` (front camera rPPG), with mock variants for the simulator. |
| `HEML` | On-device CoreML wrapper with an honest fallback: when no trained model ships, inference returns nothing and the DSP result stands (no fabricated metrics). |
| `HEPersistence` | Encrypted local store (AES-GCM + Keychain, quarantine-on-corruption), HealthKit bridge, trends/streaks, PDF/CSV export. |
| `HEFeatures` | Screens, view models, navigation; wires everything together. |

Dependency direction is strictly downward; `HECore` depends on nothing.

## Capture pipeline

```
acquire (CardioSensor → AsyncStream<SignalFrame>)
  → live SQI coaching (SQIClassifier — actionable issues, never fabricated metrics)
  → capture window (finger PPG: user-paced start/finish; min 20 s)
  → bandpass filter → peak detection → HR/HRV features
  → optional on-device inference (only if a real model is bundled)
  → CardioReading (metrics, confidence, tier, provenance, SQI, interpretation)
```

A reading that fails the SQI gate produces coaching, not numbers. Low-
confidence results offer a recheck pathway.

## Building

```sh
brew install xcodegen        # once
xcodegen generate            # produces DailyDil.xcodeproj from project.yml
open DailyDil.xcodeproj      # scheme: DailyDil
```

Unit tests (DSP + core contracts) run via the DailyDil scheme or directly on
the package: `HECoreTests`, `HESignalTests`.

- Deployment target: iOS 17. Swift 6.
- Signing: automatic, team set in `project.yml`.
- Version/build: `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in
  `project.yml` — bump the build number before each TestFlight upload.

## Privacy

- Camera frames are processed on-device and never stored or uploaded.
- Readings are AES-GCM encrypted at rest; the key lives in the Keychain
  (`ThisDeviceOnly`).
- HealthKit read/write is optional and permission-gated; camera-based wellness
  estimates are written to Apple Health only after the user approves access.
- No accounts, no ads, no tracking. See the in-app Privacy Policy for the
  authoritative copy.
