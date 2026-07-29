# OverPar Release 1.0 shipping checklist

**Prepared:** 29 July 2026  
**Target:** Native iPhone app distributed through Xcode, TestFlight and the App Store  
**Cost target:** Free services wherever possible

## The honest cost answer

The application, Xcode, device testing, SwiftUI, Core Location and AVFoundation can be used without buying third-party services. Google currently prices native Maps SDK for iOS mobile usage at unlimited free usage, but requires a billing-enabled Cloud project and restricted API key.

Public App Store/TestFlight distribution normally cannot be done for zero cost. Apple currently charges **US$99 per membership year**, converted to local currency. Apple offers fee waivers only to qualifying nonprofit organisations, accredited educational institutions and government entities—not ordinary individuals or sole traders. Sources: [Apple enrolment](https://developer.apple.com/programs/enroll/) and [membership comparison](https://developer.apple.com/support/compare-memberships/).

If Zac is eligible through a qualifying organisation, request the waiver during organisation enrolment. Otherwise the Apple membership is the one unavoidable shipping expense.

## Free Release 1.0 stack

| Need | Free choice | What it supplies |
|---|---|---|
| iOS client | SwiftUI and Apple frameworks | Native UI, camera, GPS, local storage |
| Hole-logging satellite map | Google Maps SDK for iOS | Google satellite imagery; currently unlimited free native mobile usage, with Apple satellite fallback |
| Backend | Supabase Free | PostgreSQL, PostGIS, Auth, REST, Realtime and Storage |
| Database schema | Included SQL migration | Versioned community courses and private user data |
| Email/password | Supabase Auth | Account sessions and recovery |
| Apple login | AuthenticationServices + Supabase Auth | Native Sign in with Apple |
| Google login | Google OAuth + Supabase Auth | Google account sign-in |
| Landing/privacy pages | GitHub Pages | Free public URLs for App Review and legal documents |
| Source/build automation | GitHub Free + Xcode locally | Source control; archive/sign in Xcode |
| Crash reporting initially | Xcode Organizer | Apple crash reports without another SDK |

Do not create or use a Google map ID: Google documents that map-ID cloud customisation can trigger the paid Dynamic Maps SKU. Enable only **Maps SDK for iOS**, do not enable Street View, and restrict the key both to `com.zacwhittaker.overpar` and to Maps SDK for iOS. Under Google's current price list this path has no usage charge. Billing verification may show a temporary authorisation hold or a £0 transaction; Google says that is not a charge. Pricing can change, so review the SKU before future releases.

Supabase currently advertises a Free plan with 50,000 monthly active users, 500 MB database, 1 GB file storage and 5 GB egress; free projects can pause after a week of inactivity. Check its live pricing before release.

### Zero-usage-charge Google Maps setup

1. Create a dedicated Google Cloud project named `OverPar iOS Maps`.
2. Attach a billing account. A payment method is required; a temporary verification hold or £0 transaction is possible.
3. Open **APIs & Services → Library**, search for **Maps SDK for iOS**, and enable only that SDK.
4. Do not enable Dynamic Street View, Places, Routes, Geocoding, Map Tiles or other billable APIs for this project.
5. Do not create a map ID or select cloud map styling.
6. Open **APIs & Services → Credentials → Create credentials → API key**.
7. Edit the key. Under **Application restrictions**, select **iOS apps** and add `com.zacwhittaker.overpar`.
8. Under **API restrictions**, select **Restrict key** and choose only **Maps SDK for iOS**.
9. Save and wait several minutes for the restrictions to propagate.
10. Put the key after `OVERPAR_GOOGLE_MAPS_API_KEY =` in the ignored local `OverPar/ShippingConfiguration.xcconfig`.
11. Add a £1 budget alert as notification-only defence, then periodically verify that Maps SDK is the project's only enabled Maps API.

The budget alert is not a hard spending cap. The zero-usage-charge result comes from using only the currently unlimited-free native Maps SDK SKU and blocking the key from all billable APIs. If Google changes that SKU's price, remove the key or disable billing; OverPar will automatically fall back to Apple satellite mapping.

The 1 GB free Storage allowance is the likely first limit because golf videos are large. Release 1.0 should keep originals on-device by default and make cloud upload optional. A 100 MB average clip would exhaust 1 GB after roughly ten uploaded clips, so unlimited cloud video cannot honestly be promised for free.

## Exactly what Zac must provide after the native build

### 1. Apple/Xcode identity

Provide or configure locally:

- Apple Account signed into Xcode;
- Apple Developer Team ID;
- unique registered bundle identifier—the project proposes `com.zacwhittaker.overpar`;
- whether the seller should be Zac’s legal personal name or a registered organisation name;
- Apple Developer Program membership, or confirmation of an approved organisational fee waiver;
- App ID with **Sign in with Apple** enabled;
- Xcode automatic-signing permission for that App ID.

Do not send certificates, private keys or passwords in chat. Select the team in Xcode locally.

### 2. Supabase Free project

Create one project at [supabase.com](https://supabase.com), choose the closest free region, then provide only:

- Project URL: `https://<project-ref>.supabase.co`
- publishable/anon client key: `sb_publishable_...`
- project reference ID

The publishable key is intended for clients and is constrained by Row Level Security. Never provide or embed:

- `service_role` key;
- database password;
- user access tokens;
- Apple `.p8` signing key;
- Google client secret.

Run [`supabase/migrations/202607290001_release_1.sql`](../supabase/migrations/202607290001_release_1.sql) in the Supabase SQL editor. It creates PostGIS course geometry, immutable revisions, holes, profiles, bags, range hits, rounds, shots, Gallery metadata, public nearby/search functions, private Storage and RLS policies.

Then:

1. Confirm PostGIS is enabled.
2. In Auth URL Configuration, set the iOS redirect URL chosen for the app, such as `overpar://auth-callback`.
3. Keep email confirmation on for public accounts.
4. Configure SMTP later if Supabase’s included email limits become unsuitable; do not pay until actual usage requires it.
5. Never make the `private-gallery` bucket public.

### 3. Sign in with Apple

For native-only Sign in with Apple:

- enable the capability on the App ID;
- keep the Xcode entitlement already included;
- enable Apple in Supabase Auth;
- provide the registered iOS bundle ID as the Apple client ID.

Native AuthenticationServices is preferred. Apple supplies a user’s name only on first authorisation, so OverPar must save it immediately. Supabase documents the current setup at [Login with Apple](https://supabase.com/docs/guides/auth/social-login/auth-apple).

If a future website also uses Apple OAuth, Zac will additionally need an Apple Services ID, website domain, return URL, Team ID, Key ID and `.p8` signing key. That OAuth secret must be stored only in Supabase and rotated as required; never put it in the app repository.

### 4. Google login

Create a free Google Cloud project and Google Auth Platform configuration:

- OAuth consent screen app name: `OverPar`;
- support email;
- public privacy-policy and terms URLs;
- scopes limited to `openid`, email and profile;
- iOS OAuth client using the final bundle identifier;
- web OAuth client for Supabase, with the Supabase callback URL shown in the dashboard;
- Google iOS Client ID;
- reversed client-ID URL scheme if the chosen native Google SDK requires it.

Put the Google **client secret only in Supabase**, never in the iOS app. Supabase’s official setup is [Login with Google](https://supabase.com/docs/guides/auth/social-login/auth-google).

### 5. Configuration values

Copy `OverPar/ShippingConfiguration.example.xcconfig` to the gitignored `OverPar/ShippingConfiguration.xcconfig` and enter:

```text
OVERPAR_SUPABASE_URL
OVERPAR_SUPABASE_PUBLISHABLE_KEY
OVERPAR_GOOGLE_IOS_CLIENT_ID
OVERPAR_BUNDLE_IDENTIFIER
DEVELOPMENT_TEAM
```

The Xcode project then needs the config file assigned to Debug/Release configurations. Secrets that grant privileged access never belong in this file.

### 6. Public legal/support pages

Provide final text and publish free static pages through GitHub Pages:

- privacy policy;
- terms of use;
- support/contact page;
- account-deletion instructions;
- map attribution statement;
- community course contribution/moderation policy;
- user-media retention and deletion policy;
- statement that location and videos are not used to train models without separate consent.

Provide the final HTTPS URLs for App Store Connect and the app’s Settings page. A support email controlled by Zac is also required operationally.

### 7. App Store listing material

Provide:

- final app name and subtitle;
- primary and secondary App Store categories;
- description, keywords and promotional text;
- support URL, privacy URL and marketing URL;
- age-rating questionnaire answers;
- whether the app is entirely free and contains no advertising;
- copyright owner/year;
- App Review contact name, phone and email;
- review notes explaining GPS, community course creation and camera use;
- a test account if review cannot reach all features without login;
- required iPhone screenshots captured from the final build;
- final 1024×1024 icon approval.

Complete App Privacy answers consistently with `PrivacyInfo.xcprivacy`, including precise location, account/profile information, user videos and gameplay/product-interaction data. Answers must reflect the actual configured backend—not intentions.

### 8. Course/community launch data

Before public launch:

- decide who may publish immediately and who requires moderation;
- nominate the first moderator account;
- supply a report/support email;
- seed at least a small set of legally user-created or permissioned courses;
- check duplicates and geometry in person;
- never scrape proprietary course maps or scorecards;
- retain source evidence for official rating/slope values;
- write a correction, rollback and takedown procedure.

The SQL intentionally allows authenticated users to create drafts but not self-publish them. Publishing should be a privileged server/moderator action, preventing a modified client from bypassing review.

### 9. Final Xcode release actions

After the values and accounts above exist:

1. Install the full current Xcode release.
2. Open `OverPar.xcodeproj`.
3. Select the Apple Team and registered bundle identifier.
4. Confirm Sign in with Apple capability and entitlements.
5. Add the official Supabase Swift package and optional Google Sign-In package only if those integrations use their SDKs.
6. Connect `ShippingConfiguration.xcconfig`.
7. Build on the newest supported iPhone simulator and at least one real iPhone.
8. Test denied/approximate/precise location, camera denial, airplane mode, app termination during a round, low storage, large Dynamic Type and Reduce Motion.
9. Run unit/UI tests and archive validation.
10. Create the App Store Connect record, upload the archive, answer export-compliance questions, use TestFlight, then submit for review.

## Things that cannot be made production-real before Zac supplies them

- authenticated Supabase sessions without a project URL/key;
- Apple sign-in without an App ID/team capability;
- Google sign-in without OAuth clients;
- permanent cross-device community sync without the Supabase project;
- public legal URLs without approved policy text;
- App Store signing/upload without Developer Program membership;
- automatic visual ball tracking without trained/validated on-device models and a device test corpus.

These are external identities, credentials, legal decisions or validation data—not UI placeholders. The native app retains working local/offline behaviour while they are being configured.
