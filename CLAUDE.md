# Group Point — Claude Code Context

Auto-loaded at session start. Keeps Claude up to speed on where we are without re-reading the whole project.

---

## App identity

- **Display name:** Group Point (renamed from "Group Planner" — taken on App Store)
- **Bundle ID (iOS):** `com.jmiklanek.groupplanner` (internal, NOT shown to users — kept original for cert stability)
- **Package name (Android):** same path, not yet configured for store
- **Tagline:** "Find the date that works"
- **Version:** 1.0.0+1 (in pubspec). Bump when iterating.
- **Developer:** Jakub Miklánek, Slovakia, jakub.miklanek@gmail.com
- **Apple Team ID:** `JZC8J8KMKN`

## What it does

Helps friend groups pick a meetup date. Members mark their availability per date (Available / Likely / Maybe / Unavailable), the app suggests the optimal date. Inspired by Tricount's UX.

---

## Tech stack

- **Frontend:** Flutter (Dart 3.11.5)
- **State:** Riverpod (`flutter_riverpod`)
- **Auth:** Firebase Auth — Google, Apple, Email/Password
- **DB:** Firestore (cloud_firestore)
- **Calendar:** `table_calendar` package
- **Sharing:** `share_plus`
- **Persisted prefs:** `shared_preferences`
- **Launcher icons:** `flutter_launcher_icons`
- **Splash:** `flutter_native_splash`

## Project structure (key files)

```
lib/
├── main.dart                                 # MaterialApp + theme + routing
├── core/
│   ├── design_tokens.dart                    # AppColors, AppSpacing, AppRadius, AppText — single source of truth for theme
│   └── theme_provider.dart                   # ThemeMode + start day of week prefs
├── features/
│   ├── auth/
│   │   ├── sign_in_screen.dart               # Google / Apple / Email
│   │   └── email_sign_in_screen.dart         # Email sign up / sign in
│   ├── onboarding/
│   │   ├── onboarding_provider.dart
│   │   └── onboarding_screen.dart            # 4-slide intro on first launch
│   ├── groups/
│   │   ├── models/group_model.dart           # GroupModel with tripLength, window, memberNames map
│   │   ├── providers/
│   │   │   ├── groups_provider.dart          # active / archived / single group, CRUD
│   │   │   └── activity_provider.dart        # group activity feed
│   │   ├── widgets/trip_settings.dart        # shared widget for create/edit
│   │   └── screens/
│   │       ├── groups_screen.dart            # main list (Tricount-style cards)
│   │       ├── create_group_screen.dart
│   │       ├── edit_group_screen.dart
│   │       ├── join_group_screen.dart
│   │       ├── group_detail_screen.dart      # tabs: Calendar / Members / Activity
│   │       └── group_details_screen.dart     # full per-member breakdown
│   ├── availability/
│   │   ├── providers/availability_provider.dart  # 4 statuses, per-user
│   │   └── screens/availability_screen.dart      # cycle, multi-select mode, group-by-range list
│   └── profile/
│       ├── services/account_deletion.dart   # full data + auth wipe (Apple App Store req)
│       └── screens/
│           ├── profile_screen.dart           # avatar, name, nickname, options, archived, about
│           └── legal_screen.dart             # Privacy + Terms (in-app)

assets/
├── app_icon.png                              # 1024×1024 GP-in-Venn icon
└── icon_backup_flutter_default/              # original Flutter icon (revertable)

docs/                                         # GitHub Pages — public legal site
├── index.html
├── privacy.html
└── terms.html
# Live at: https://jxkxx.github.io/group-planner/
```

---

## Firebase setup

- **Project:** `group-planner-65c05`
- **Rules:** in `firestore.rules` (committed), deployed via `firebase deploy --only firestore:rules`
- **Collections:**
  - `users/{uid}` — displayName, nickname, availableDates, likelyDates, maybeDates, unavailableDates
  - `groups/{groupId}` — name, emoji, createdBy, createdAt, inviteCode, memberIds, archivedBy, memberNames, tripLength, tripLengthTolerance, windowStart, windowEnd, showUnavailableDates
  - `groups/{groupId}/activity/{id}` — uid, action, date, timestamp
  - `groups/{groupId}/availabilities/{uid}` — per-group availability override
- **Auth providers enabled:** Google, Apple, Email/Password

## Known v1 security caveat

Any authenticated user can read any `users/{uid}` doc (needed to render group members). A malicious authed user could scrape availability. Acceptable for v1; future fix = Cloud Function for member resolution.

---

## Apple / App Store status (as of last session)

- ✅ Apple Developer Program enrolled (Team JZC8J8KMKN)
- ✅ Distribution certificate created (in Keychain)
- ✅ Bundle ID registered with Sign In with Apple capability
- ✅ App Store Connect app created: **Group Point**
- ✅ First build (1.0.0 build 1) uploaded via Xcode Organizer
- ✅ Build status: **Complete** (encryption compliance answered: "None of the algorithms mentioned above")
- ✅ Test Information filled in
- ✅ External Testing group "Beta testers" created
- ✅ Submitted for **Beta App Review** (waiting for Apple, 12-48h typical)
- ✅ Public TestFlight link enabled (will go live after beta approval)

## Public URLs

- Landing + legal: https://jxkxx.github.io/group-planner/
- Privacy: https://jxkxx.github.io/group-planner/privacy.html
- Terms: https://jxkxx.github.io/group-planner/terms.html

---

## Design system (use these — don't hardcode)

`lib/core/design_tokens.dart`:

- `AppColors.{available|likely|maybe|danger|info|accent|purple|brandPrimary|brandPrimaryDark|lightBg|lightSurface|darkBg|darkSurface|...}`
- `AppColors.avatarFor(name)` — stable color from string
- `AppSpacing.{xxs|xs|sm|md|lg|xl|xxl|x3..x7}`
- `AppRadius.{xs|sm|md|button|card|sheet|pill}`
- `AppText.{titleXl|titleLg|titleMd|titleSm|bodyLg|bodyMd|bodySm|bodyXs|labelLg|labelMd|labelSm|codeLg}`
- `AppIconSize.{xs|sm|md|lg|xl}`
- `AppDecorations.card(context)` / `.tintedIcon(color)` / `.pill(color)`

When adding new screens or refactoring, **always pull from tokens** rather than hardcoding colors.

---

## Common commands

```bash
# Run on iPhone 17 simulator (id may change)
flutter run -d 539D77F3-F55C-4B7C-A077-54BDBC82432C

# Or generic
flutter run -d ios

# Build signed App Store IPA
flutter build ipa --release
# Output: build/ios/ipa/Group Point.ipa
# If codesign fails: open the .xcarchive in Xcode and use Distribute App flow

# Regenerate launcher icons (after replacing assets/app_icon.png)
dart run flutter_launcher_icons

# Regenerate splash (after icon/color changes in pubspec.yaml)
dart run flutter_native_splash:create

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Push docs to GitHub Pages
git add docs/ && git commit -m "..." && git push
```

---

## Current sprint focus

1. **Beta App Review** in progress (Apple, waiting)
2. **App Store v1.0 submission** in parallel — fill listing fields, upload screenshots, App Privacy nutrition labels, age rating, submit
3. **Bug fixes from TestFlight beta** as friends report

## Open todos for v1 launch

- [ ] App Store listing copy filled in (subtitle/description/keywords/promo) — listing copy is written, paste into Distribution page
- [ ] App Store screenshots (5-6 from simulator, 6.7" iPhone size: 1290×2796)
- [ ] Pricing & Availability set (Free, all countries)
- [ ] Age Rating questionnaire (answer 4+)
- [ ] App Privacy nutrition labels (data we collect: email, name, photo, availability, group membership)
- [ ] Submit for App Review (separate from Beta Review)

## Known cleanups (low priority)

- A few unused imports / dead fields in `profile_screen.dart` (`_datesExpanded`)
- `_OptimalDateCard` reference removed but file might still have stale comments
- Linter warnings remain for `unnecessary_underscores`, `unused_field` — non-blocking

---

## Conventions

- **Don't create new files unless explicitly necessary** — edit existing
- **Never commit secrets** — Firebase API keys are public by design (Firestore rules are the guard)
- **Use tokens, not hardcoded colors** — see `design_tokens.dart`
- **Direct responses, no fluff** — user prefers short, decisive answers (developer with limited time)
- **Slovakia jurisdiction** in legal docs
- **Email obfuscation** in public HTML (JS reveal pattern, see `docs/*.html`)

## Quick "where are we" check at session start

If unsure of state, check:
1. `git log --oneline -10` — recent commits
2. `git status` — uncommitted work
3. App Store Connect → TestFlight tab — beta status
4. App Store Connect → Distribution tab — v1.0 listing status
