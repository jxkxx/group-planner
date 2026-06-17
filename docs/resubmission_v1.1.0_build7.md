# Resubmission — v1.1.0 build 7 (after Jun 15 2026 rejection)

Rejection reasons (build 2): (1) Sign in with Apple errored; (2) needed a demo account.
Both fixed in build 7. Sign in with Apple verified working on device.

## Demo account (verified working)
- Email: `appreview@grouppoint.app`
- Password: `GroupPoint2026!`
- Pre-populated with group "Ski Trip 2026" (4 members + availability, optimal date Sat Jun 27).

## Steps in App Store Connect
1. Distribution → version **1.1.0** → **Build** section → remove old build → **Add Build → 1.1.0 (7)**.
2. **App Review Information**:
   - Sign-in required: checked
   - User name: `appreview@grouppoint.app`
   - Password: `GroupPoint2026!`
   - Notes: (below)
3. **Resolution Center** → Reply (below).
4. **Add for Review → Submit**.

## App Review — Notes field
```
Sign in with Apple is fully working in this build.

A demo account is provided in the Sign-In Information fields above. It is
pre-populated with a sample group ("Ski Trip 2026") demonstrating all
features. On the launch screen, tap "Continue with Email" and enter the
credentials, or use "Continue with Apple". Account deletion is under
Profile → Delete Account.
```

## Resolution Center — Reply
```
Hello,

Both issues are resolved in build 7:

1. Sign in with Apple (2.1): caused by a nonce-forwarding bug in the auth
flow. It now uses the managed Apple provider flow and signs in
successfully (verified on a physical device).

2. Demo account (2.1 Information Needed): credentials are in the App
Review Information section (appreview@grouppoint.app), pre-populated with
sample data so all features can be reviewed.

Thank you!
```
