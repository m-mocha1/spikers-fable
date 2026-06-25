# Store privacy forms — Spikers

These are the answers to fill into **Apple App Privacy** (App Store Connect) and **Google Play Data
Safety** (Play Console). They are derived from what the app's code actually collects. Keep this file in
sync with the privacy policy (`privacy-policy.html`) — the stores compare the two.

Key facts that drive every answer:
- **No third-party analytics or ads SDK** (no `firebase_analytics`, no Crashlytics, no ad networks).
- **No payment processing in the app** — membership "paid/unpaid" is set manually by staff. No card/bank data.
- Backend is **Firebase (Google)** acting as a data **processor** on our behalf.
- Nothing is used for **cross-app tracking** → no ATT prompt required.

---

## Apple — App Privacy label

Overall: **Data is collected.** For every type below: **Linked to the user = Yes**,
**Used for tracking = No**, **Purpose = App Functionality** (none for analytics/advertising/tracking).

| Apple data type | Specific data | Notes |
|---|---|---|
| **Contact Info** | Email Address, Name | From Firebase Auth / profile |
| **User Content** | Photos or Videos | Profile photo only, when the user chooses one |
| **Health & Fitness** | Fitness | Height & weight on the player profile (judgment call — declare honestly) |
| **Identifiers** | User ID | Firebase UID |
| **Identifiers** | Device ID | FCM push token / device identifier |
| **Other Data Types** | Date of birth, gender, membership & attendance status | No dedicated Apple type for these |

Because nothing is used for tracking, answer **"No"** to the tracking question — **no
AppTrackingTransparency prompt is needed.**

> Do **not** tick "Purchases" / "Financial Info" — the app processes no payments.
> Only declare "Health & Fitness" if you keep height/weight; if you drop those fields, remove this row.

---

## Google Play — Data Safety form

### Data collection & sharing
- **Does your app collect or share any of the required user data types?** → **Yes**
- **Is all data encrypted in transit?** → **Yes**
- **Do you provide a way for users to request that their data be deleted?** → **Yes**
  (in-app: Profile → Settings → Delete Account; plus deletion request URL/email)

For every type below: **Collected = Yes**, **Shared = No** (Firebase is a processor, which Google does
**not** count as "sharing"), **Processed ephemerally = No**, **Purposes = App functionality + Account
management**. "Required" vs "Optional" as noted.

| Google Play category → type | Data | Required/Optional |
|---|---|---|
| **Personal info → Name** | Display name | Required |
| **Personal info → Email address** | Account email | Required |
| **Personal info → User IDs** | Firebase UID | Required |
| **Personal info → Other info** | Date of birth, gender | Optional |
| **Photos and videos → Photos** | Profile photo | Optional |
| **Health and fitness → Fitness info** | Height, weight | Optional (judgment call) |
| **Device or other IDs → Device or other IDs** | FCM push token | Required |

Do **not** declare **Financial info** (no purchases/transactions occur in the app) and do **not**
declare **App activity / analytics** (no analytics SDK).

### Data deletion details (Google Play)
- Provide the **account-deletion URL** (your hosted policy / a help page that explains the in-app path).
- State that deletion is **in-app and self-service**, with an email fallback.

### Target audience & content (decide this — see policy §9)
- If minors use the app → declare a mixed/under-18 target audience and comply with the **Play Families**
  policy (parental consent, etc.).
- If 16+ only → declare adult audience and enforce an age check at registration.
- This **must** match your App Store age rating.

---

## Before you submit — checklist
- [ ] Self-service "Delete Account" actually ships in the build you submit (policy §8 now promises it).
- [ ] `CONTACT_EMAIL_HERE` replaced everywhere in the policy with a real, monitored address.
- [ ] Children section (§9) decided and consistent with store age settings.
- [ ] Policy hosted at a public HTTPS URL; that URL entered in both consoles.
- [ ] Apple label + Play Data Safety match the policy and the tables above.
- [ ] iOS `Info.plist` has `NSCameraUsageDescription` and `NSPhotoLibraryUsageDescription` strings.
