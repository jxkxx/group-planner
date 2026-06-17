# Group Point — Claude Code Context

Auto-loaded at session start. Keeps Claude up to speed without re-reading the whole project.

---

## App identity

- **Display name:** Group Point
- **Bundle ID (iOS):** `com.jmiklanek.groupplanner` (internal, never shown to users)
- **Tagline:** "Find the date that works"
- **Version:** **1.1.0+7** in pubspec — build 7 fixes Sign in with Apple; resubmitted to App Store after the build-2 rejection
- **Developer:** Jakub Miklánek, Slovakia, jakub.miklanek@gmail.com
- **Apple Team ID:** `JZC8J8KMKN`

## Paradigm (v1.1.0)

- **Personal calendar** = mark when you CAN'T travel. Only 2 statuses: **Unavailable** (red) and **Maybe Unavailable** (amber).
- **Group calendar** = per-group availability (members opt in for available/likely/maybe). Personal Unavailable → group sees as Unavailable by default (overridable per-group).
- Subtitle on Availability tab: "Mark when you can't travel".
- Personal **legacy fields are ignored** when computing group views (`availableDates`/`likelyDates`/`maybeDates` no longer read from personal).
- Personal write clears all 5 fields (both new + legacy) so data stays clean.

## Tech stack

Flutter (Dart 3.11.5) · Riverpod · Firebase Auth (Google/Apple/Email) · Firestore · table_calendar · share_plus · shared_preferences · flutter_launcher_icons · flutter_native_splash.

## Project structure (key files)

```
lib/
├── main.dart                                 # MaterialApp + theme + routing
├── core/
│   ├── design_tokens.dart                    # AppColors, AppSpacing, AppRadius, AppText
│   └── theme_provider.dart                   # ThemeMode + week-start + select-tutorial-seen
├── features/
│   ├── auth/                                 # sign_in_screen.dart, email_sign_in_screen.dart
│   ├── onboarding/                           # 4-slide intro on first launch
│   ├── availability/
│   │   ├── providers/availability_provider.dart   # DateStatus + PersonalDateStatus enums
│   │   └── screens/availability_screen.dart       # 2-status personal calendar
│   ├── groups/
│   │   ├── models/group_model.dart           # tripLength, window, minHeadcount, confirmations
│   │   ├── providers/
│   │   │   ├── groups_provider.dart          # CRUD + setMyOverrideInGroup + toggleConfirmation
│   │   │   └── activity_provider.dart        # group activity feed
│   │   ├── widgets/
│   │   │   ├── trip_settings.dart            # shared widget (length+tol, range, headcount)
│   │   │   └── emoji_data.dart               # ~290 emojis in 10 categories
│   │   └── screens/
│   │       ├── groups_screen.dart            # Tricount-style card list
│   │       ├── create_group_screen.dart
│   │       ├── edit_group_screen.dart
│   │       ├── join_group_screen.dart
│   │       ├── group_detail_screen.dart      # 3 tabs: Calendar / Members / Activity
│   │       └── group_details_screen.dart     # per-member dates breakdown
│   └── profile/
│       ├── services/account_deletion.dart   # full data + auth wipe (Apple App Store req)
│       └── screens/
│           ├── profile_screen.dart           # avatar, name, nickname, options, archived
│           └── legal_screen.dart             # Privacy + Terms in-app

assets/
├── app_icon.png                              # 1024×1024 GP-in-Venn icon
└── icon_backup_flutter_default/              # original Flutter icon (revertable)

docs/                                         # GitHub Pages — public legal site
├── index.html
├── privacy.html
└── terms.html
# Live at: https://jxkxx.github.io/group-planner/
```

## Firebase

- **Project:** `group-planner-65c05`
- **Rules:** `firestore.rules` (committed), deployed via `firebase deploy --only firestore:rules`
- **Collections:**
  - `users/{uid}` — displayName, nickname, unavailableDates, maybeUnavailableDates (legacy availableDates/likelyDates/maybeDates ignored)
  - `groups/{groupId}` — name, emoji, createdBy, createdAt, inviteCode, memberIds, archivedBy, memberNames, tripLength, tripLengthTolerance, windowStart, windowEnd, **minHeadcount**, **confirmations** {date→[uids]}
  - `groups/{groupId}/activity/{id}` — uid, action, date, timestamp
  - `groups/{groupId}/availabilities/{uid}` — per-group availability override (4 statuses)
- **Auth providers enabled:** Google, Apple, Email/Password

## Known v1 security caveat

Any authenticated user can read any `users/{uid}` doc. Acceptable for v1; future fix = Cloud Function for member resolution.

---

## v1.1.0 — what shipped since v1.0.0-tf1

| # | Feature |
|---|---|
| **1** | Personal calendar redesigned — 2 statuses (Unavailable + Maybe Unavailable), new subtitle |
| **2** | Multi-select in group calendar — "Select dates" → tap many → apply status |
| **3** | First-time popup on Availability tab explaining Select feature |
| **4** | Sync warning — group Available conflicts with personal Unavailable |
| **5** | Confirmation flow — members confirm optimal date, "all confirmed" prompts block in personal |
| **6** | Required headcount — toggle in trip settings. Calendar greens scale 50%→100% of min |
| **7** | Tap a member in Members tab → opens their per-status date breakdown |
| **8** | "Show all votes" replaced by dropdown — pick which statuses appear as dots |
| **9** | Subtle "Group Point" brand pill on empty states |
| **fix** | Sync issue — personal write clears legacy fields; groups ignore legacy fields |
| **fix** | Calendar cell alignment — wrapped in fixed 40×40 SizedBox |
| **fix** | Required headcount row overflow — wrapped label in Expanded |
| **fix** | Removed redundant "Show unavailable dates" toggle |
| **fix** | Expanded emoji list to ~290 across 10 categories (Travel, Party, Food, Sports, Beach, 4× Flag regions, Other) |

Git tags: `v1.0.0-tf1` (first TestFlight submission, snapshot before v1.1 paradigm shift).

## Apple / App Store status

- ✅ Apple Developer Program enrolled (Team JZC8J8KMKN)
- ✅ Distribution certificate created
- ✅ Bundle ID registered with Sign In with Apple capability
- ✅ App Store Connect app created: **Group Point**
- ✅ v1.0.0 build 1 uploaded + submitted for Beta App Review (status unknown — check App Store Connect)
- ✅ External Testing group "Beta testers" created
- ✅ Public TestFlight link enabled
- ✅ **v1.1.0 (build 2) built, uploaded, and shipped to TestFlight (Jun 4 2026)** — attached to Friends (internal) + Beta testers (external)
- ✅ **v1.1.0 SUBMITTED to public App Store (Jun 10 2026)** — First-ever public submission. Listing: Travel/Productivity, Free, all 175 regions, 4+, iPhone+iPad (Mac/Vision Pro disabled). Listing copy: `docs/appstore_listing_v1.1.0.md`.
- ❌ **REJECTED (Jun 15 2026, build 2):** (1) Sign in with Apple errored; (2) needed a demo account. Both fixed → **resubmitted with build 7**.
- 🔑 **Demo account for App Review:** `appreview@grouppoint.app` / `GroupPoint2026!` (email/password, Firebase uid xkCjf3z90RNyRAIB90SR7NY78CY2). Pre-populated with group "Ski Trip 2026" (doc id `demo_weekend_trip`) + fake members + availability. Keep this account for future reviews.
- ⚠️ **Sign in with Apple was broken in 5 stacked ways** (each fixed in sequence; see [[Apple Sign-In debugging]]):
  1. **Missing entitlement** → `AuthorizationError 1000` on device. Fixed: added `ios/Runner/Runner.entitlements` (`com.apple.developer.applesignin`) + `CODE_SIGN_ENTITLEMENTS` in all 3 Runner build configs.
  2. **Apple provider not enabled in Firebase** → `operation-not-allowed`. Fixed: enabled `apple.com` defaultSupportedIdpConfig (native iOS: `appleSignInConfig.bundleIds=[com.jmiklanek.groupplanner]`, no clientId).
  3. **iOS app missing Apple Team ID in Firebase** → set teamId=JZC8J8KMKN on the Firebase iOS app (via Firebase Mgmt API). (Necessary but not sufficient.)
  4. **firebase_auth 6.4.0 manual-credential bug** → `OAuthProvider('apple.com').credential(rawNonce:)` does NOT forward the raw nonce to `signInWithIdp`, so the backend rejects valid tokens with `invalid-credential / Invalid OAuth response from apple.com`. PROVEN by a diagnostic build: a direct `signInWithIdp` REST call WITH `nonce=<rawNonce>` in postBody returned HTTP 200 with the identical token. **Fix: use `FirebaseAuth.signInWithProvider(AppleAuthProvider()..addScope('email')..addScope('name'))`** (managed native flow forwards the nonce internally). See `sign_in_screen.dart`. Verified working on device in build 7.
  - ⚠️ **objective_c pod (9.3.0) device-build bug:** its arm64 slice ships with the iOS *Simulator* platform marker (platform 7), failing Transporter validation (err 409, then err 90208 minos mismatch). **The fix is a post-build patch, NOT a Podfile change.** (An `EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64` Podfile guard was tried in c8663e6 but REVERTED in e41cdcb — it breaks running on Apple Silicon simulators and didn't fix the device bug.) **To fix a failing upload:** in the built `.xcarchive`, patch the framework binary with `vtool -set-build-version ios 13.0 18.2 -replace -output <bin> <bin>` (minos 13.0 must match the framework Info.plist MinimumOSVersion; check the Flutter.framework for the right sdk), re-sign with `codesign --force --sign "Apple Distribution: ..."`, re-export via `xcodebuild -exportArchive`, then upload.

## Public URLs

- Landing + legal: https://jxkxx.github.io/group-planner/
- Privacy: https://jxkxx.github.io/group-planner/privacy.html
- Terms: https://jxkxx.github.io/group-planner/terms.html

---

## Design system

Use tokens, never hardcoded colors:

- `AppColors.{available|likely|maybe|danger|info|accent|purple|brandPrimary|brandPrimaryDark|lightBg|lightSurface|darkBg|darkSurface|...}`
- `AppColors.avatarFor(name)` — stable color from string
- `AppSpacing.{xxs|xs|sm|md|lg|xl|xxl|x3..x7}`
- `AppRadius.{xs|sm|md|button|card|sheet|pill}`
- `AppText.{titleXl|titleLg|titleMd|titleSm|bodyLg|bodyMd|bodySm|bodyXs|labelLg|labelMd|labelSm|codeLg}`
- `AppIconSize.{xs|sm|md|lg|xl}`
- `AppDecorations.card(context)` / `.tintedIcon(color)` / `.pill(color)`

## Common commands

```bash
# Run on iPhone 17 simulator (id may change after Xcode updates)
flutter run -d B152114A-2BA9-452F-A5C4-93EB559D30BE

# Build App Store IPA
flutter build ipa --release
# Output: build/ios/ipa/Group Point.ipa
# If codesign fails on export → open the .xcarchive in Xcode + Distribute App flow

# Regenerate launcher icons (after replacing assets/app_icon.png)
dart run flutter_launcher_icons

# Regenerate splash (after changes in pubspec.yaml)
dart run flutter_native_splash:create

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Push docs to GitHub Pages
git add docs/ && git commit -m "..." && git push
```

---

## Current sprint focus

**v1.1.0 (build 2) SUBMITTED to the public App Store — Waiting for Review (Jun 10 2026).** Next steps:
1. Wait for Apple review email (first full review usually 24–48h). Watch for rejection reasons (most likely: login access — mitigated via Sign in with Apple note; or metadata).
2. If approved → app goes live (or set to manual release in App Store Connect if you want to control timing).
3. ⚠️ **Cleanup pending:** screenshot demo data was injected into PRODUCTION Firestore via REST (fake groups Summer in Spain / Ski Weekend / Italy Food Tour, fake members Anna/Marek/Lucia/Tomáš + their availability in "Dasty's Road Trip"). Visible only to the owner account. Remove when no longer needed for re-screenshots.
4. Tester "What to Test" notes: `docs/testflight_notes_v1.1.0.md`. Listing copy: `docs/appstore_listing_v1.1.0.md`. Screenshots: `~/Desktop/GroupPoint_AppStore_Screenshots*` (iPhone 6.9"/6.5" + iPad 13").

Then back to the build plan (Week 5: Availability tab polish → Week 6: Profile → Week 7: design pass).

**Build/upload flow that worked (for next release):**
1. `flutter build ipa --release` — produces `build/ios/ipa/Group Point.ipa`
2. Upload via Transporter app (drag IPA in → Deliver). Sign in as jakub.miklanek@gmail.com (app-specific password).
3. If Transporter rejects the objective_c framework → see the pod-bug note under "Apple / App Store status" above for the vtool patch workaround.
4. App Store Connect processes (~5–15 min) → add build to test groups → answer export compliance (No, standard HTTPS exempt) → external triggers Beta App Review.

## Conventions

- **Direct, no fluff** — user is an amateur dev with limited time. Prefers short, decisive answers.
- **Don't create new files unless necessary** — edit existing
- **Never commit secrets** — Firebase API keys are public by design (rules are the guard)
- **Use design tokens** — see `design_tokens.dart`
- **Email obfuscation** in public HTML (JS reveal pattern)
- **Slovakia jurisdiction** in legal docs

## Quick "where are we" at session start

1. `git log --oneline -10` — recent commits
2. `git status` — uncommitted work
3. App Store Connect → TestFlight tab — beta status
4. `grep version pubspec.yaml` — current version

## Latest uncommitted changes

After v1.1.0 base, also done this session (not yet committed in some cases):
- "Show unavailable dates" toggle removed
- Emoji list expanded (~290 emojis, 10 categories) — shared `emoji_data.dart`
- Calendar cell wrapped in fixed-size SizedBox to fix alignment issues
- Required headcount row layout fixed (overflow)

Recommend committing before building IPA.
