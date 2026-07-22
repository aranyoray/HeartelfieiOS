# App Review Response

## Guideline 2.1 - Face Data

**What face data does the app collect?**

Heartelfie only processes face data during the optional facial rPPG wellness check. The app uses the front camera stream to locate a face region and process subtle color changes that can be used to estimate pulse for a wellness screening. Heartelfie does not create Face ID templates, does not identify the user, and does not use face data for authentication, advertising, profiling, or tracking.

**Use, sharing, retention, deletion, and storage practices**

Raw face images and video frames are processed in memory on device during the check. Raw face images and video frames are not saved to the app database, are not written to Apple Health, are not uploaded to Heartelfie servers, and are not shared with third parties. After the check ends, raw face frames are discarded. The saved reading may include derived wellness metrics, signal-quality values, timestamps, capture modality, model provenance, and a small derived waveform preview. Derived readings remain on the device until the user deletes them, exports them, or removes the app. Users can delete local Heartelfie data from the app's Data & Privacy screen.

**Will face data be shared with any third parties? Where is it stored?**

No. Face data is not sold, used for advertising, or shared with third parties. Raw face frames are processed in memory on device and are not persistently stored. Derived readings are stored locally on the user's device in an encrypted database.

**How long is face data retained?**

Raw face frames are retained only in memory during processing and are discarded immediately after the check. Derived readings are retained locally until the user deletes them, exports them, or removes the app.

**Where is this explained in the privacy policy?**

The privacy policy explains face-data collection, use, sharing, storage, retention, and deletion in these sections:

- Section 1, "Summary"
- Section 3, "Face Data"
- Section 4, "Storage, Retention, and Deletion"
- Section 6, "Sharing and Third Parties"
- Section 10, "Security"

**Specific privacy-policy text concerning face data**

Section 1 states: "Camera frames, including face frames, are processed on device and are not saved." It also states: "Face data is not sold, used for advertising, or shared with third parties."

Section 3 states: "During a facial rPPG check, Heartelfie uses the front camera video stream to locate a face region and process subtle color changes that can be used to estimate pulse for a wellness screening. This is the only face data collected by the app. Heartelfie does not create Face ID templates, does not identify you, and does not use face data for authentication, advertising, profiling, or tracking."

Section 3 also states: "Raw face images and video frames are processed in memory on the device. They are not saved to the app database, not written to Apple Health, not uploaded to Heartelfie servers, and not shared with third parties. After the check ends, raw face frames are discarded. The saved reading may include derived wellness metrics, signal-quality values, timestamps, capture modality, model provenance, and a small derived waveform preview."

Section 4 states: "Raw camera frames, including raw face frames, are retained only in memory during processing and are discarded immediately after the check. Derived readings remain on your device until you delete them, export them, or remove the app."

Section 6 states: "Heartelfie does not sell personal information or face data. We do not share face data with third parties."

## Guideline 5.1.1(iv) - HealthKit Permission Prompt

The custom HealthKit priming button has been changed from "Connect Apple Health" to "Continue" in onboarding and profile authorization flows. The UI now clearly identifies the integration as "Apple Health / HealthKit" and explains that access is optional and controlled by the Health app.

## Guideline 2.5.1 - HealthKit / CareKit Identification

The app does not use CareKit. The app uses HealthKit through the Apple Health integration only. The app UI now explicitly identifies this functionality in:

- Onboarding: "Apple Health" permission card with a neutral "Continue" action.
- Profile: "Apple Health / HealthKit" section.
- Data & Privacy: "Apple Health / HealthKit" section explaining read/write behavior.

## Guideline 1.4.1 - Safety / Medical Claims

The app has been revised to reinforce wellness-only positioning and remove reading-driven medical action CTAs. Threshold notices now tell users to retake readings and compare trends, not to seek care based on app readings. The former hospital/emergency/partner-clinic action language has been removed from reading result cards.

Heartelfie is not represented as a medical device and is not intended to diagnose, treat, cure, or prevent any disease or condition. The app should only be distributed in storefronts where the product's wellness-only claims are appropriate. If Heartelfie hardware is marketed as regulated medical hardware in any jurisdiction, attach the applicable regulatory clearance and hardware validation documentation in App Store Connect before submitting in that jurisdiction.
