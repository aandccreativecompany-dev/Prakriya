# Prakriyā

*(formerly "Ritualist")*

A daily ritual and manifestation practice app for Android — priorities,
habits, a mantra each morning, journaling, and reminders that reach you when
you're too busy to open the app. Now also covers finance (wallet, budget,
savings), health, relationships, and a shareable vision board.

Built and maintained by A&C Creative Company.

## Status

**v0.4.1** — current release, distributed as a signed APK on
[GitHub Releases](https://github.com/aandccreativecompany-dev/Prakriya/releases).
Local-first storage: your data lives on-device and everything works with no
network once set up. Signing in with Google is required to complete
onboarding (as of the Google Play submission) and adds a cloud backup of
your data under your own account — there is still no paywall, and you can
sign out again afterward from Settings without losing local access.

## What's in the app

**Core / daily practice**
- Dashboard: greeting, today's mantra, quick stats, and shortcuts to every
  section, plus a bottom nav bar — each section is its own full screen
  (no more swipe-carousel repeating the header on every page)
- Home card stack: date, mantra, top three priorities, habits — reorderable
  and hideable from Settings or the first-run quiz
- Habit streaks and a five-week history grid, with a tappable calendar
- Three daily local reminders: 7:30am mantra + priorities, a 1pm check that
  only fires if something's still open, a 9pm close-the-day
- Onboarding: welcome → a short quiz that sets a preset → the module picker.
  Runs once; retakeable from Settings any time
- Scripting (outcome engineering): write the outcome you want as if it
  already happened, with entry timestamps
- Quote of the day: today's mantra, full-screen and shareable — mantra bank
  of 153+ entries, shuffled with no-repeat-until-exhausted rotation
- Weekly and monthly goals
- Weekly momentum review: priorities finished and habit check-ins over the
  last 7 days
- Evening reflection / journaling: short prompts, locked behind an optional
  PIN with biometric unlock on top

**Finance**
- Wallet: editable monthly/weekly budget (scroll-to-select amount picker or
  manual entry) with a live spent-vs-budget progress bar
- Spending tracker with editable entries (tap to edit, not just delete) and
  a Need/Want budget calculator that pulls actual spend live from it
- Savings & investments tracking across emergency fund, stocks, mutual
  funds, gold, fixed deposits, PPF/EPF, real estate, crypto and other —
  running totals per type with logged, noted contributions
- Indian Rupee currency throughout

**Health & relationships**
- Skin Health tips (grounded, practical — no external form/webview)
- Audible-bell exercise timer
- Relationships & Connection: a "who to reach out to" tracker — set a
  check-in cadence per person, see who's overdue, log a check-in in one tap
- Mind map notes

**Vision board**
- Grid of tiles with per-tile decorative frames (polaroid, torn paper,
  washi tape, drop shadow), photo colour-grading presets (warm, dreamy,
  B&W), whimsical shapes (cloud, flower, arch, blob, plus boxes/circles/
  stars/hearts), and board-wide background themes (cork, linen, gradient,
  midnight)
- Shared vision boards: create one and get a short code, or join one with a
  code someone shared with you — anyone signed in with the code can add a
  point (text-only; no photo sync yet)

**Platform / polish**
- Google sign-in (required to finish onboarding) with Firebase-backed cloud
  backup — sync is last-write-wins, and no other feature depends on being
  signed in, so signing out afterward from Settings still leaves the app
  fully usable locally
- Android home-screen widget (habits checklist, top priority, and/or
  today's mantra — user-selectable in Settings)
- Copy-and-paste backup, for when you don't want an account
- Light and dark, following the phone, overridable in Settings
- Edge-to-edge display, tab-switch fade transitions, haptic feedback on
  habit toggles, tab switches, and saves
- "About us" screen (website/Instagram/YouTube links, moved out of the
  in-app footer)

## Not in this build

The paywall is designed (see `design/`) but deliberately not built: the app
is free of charge for now, per the product decisions in the design handoff.
It needs Google Play Billing product IDs to wire up and is future work, not
a bug. (Sign-in *is* built — see Platform / polish above.)

## Stack

- Flutter (Dart) — one codebase, Android first
- Local storage first (`shared_preferences`): the app works with no network
- Firebase (Auth, Cloud Firestore) + Google Sign-In, required at onboarding,
  backing the cloud-backup and shared-vision-board features
- Local scheduled notifications for reminders (no push infrastructure)
- Android home-screen widget via `home_widget`
- Distribution: an APK on GitHub Releases (see `docs/RELEASING.md`); Play
  Store submission is future work

## Getting started

```
flutter pub get
flutter run
```

Requires Flutter with the Android SDK. Run `flutter doctor` and clear every
warning before starting. There's no `android/` folder committed — see
"Building" below. Cloud-backup and shared-board features need a Firebase
project wired up (`google-services.json`); the rest of the app works
without one.

## Building

You don't need Flutter installed to get an APK:

- **Quick/debug build**: Actions tab → **Build APK (debug, manual)** → **Run
  workflow**. Downloads as a build artifact from the run page. No signing
  secrets required — this is what most contributors want.
- **Signed release**: push a `v*` tag. The **Release APK** workflow builds a
  signed APK and drafts a GitHub Release, but only once the repo has
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD` and `KEY_ALIAS`
  secrets set (Settings → Secrets and variables → Actions).

Both workflows generate `android/` fresh via `flutter create` and layer
`android_overrides/AndroidManifest.xml` (and the home-screen widget's native
provider/layout) on top — the repo deliberately holds no Gradle wrapper. See
`docs/RELEASING.md` for the full release process and
`docs/FINDING_BUILD_ERRORS.md` if a run fails.

## Latest release

[**Prakriyā v0.4.1**](https://github.com/aandccreativecompany-dev/Prakriya/releases/latest) —
see the [full release history](https://github.com/aandccreativecompany-dev/Prakriya/releases)
for what changed in each version (v0.4.0: bottom-nav dashboard, no-repeat
mantras, editable wallet, richer vision boards; v0.3.0: budget & savings
tracking, a journaling data-loss fix, relationship check-ins).

## Package name

`ai.aandccreative.prakriya` (renamed from `ai.aandccreative.ritualist` when the
app itself was renamed from Ritualist to Prakriyā). Treat this one as
permanent going forward — an applicationId change is a breaking change for
anyone with the app already installed (Android treats it as a different
app), so it should not happen again casually.

## Design reference

`design/AC Planner App.dc.html` holds the full 20-screen design set (dark and
light) — everything above plus the not-yet-built paywall screens. Open it in
a browser. Screens are labelled `2a` through `2t`.

`design/Ritualist - Ship to Play Store.dc.html` (filename kept from before the
rename) is the publishing guide,
including the GitHub Releases route this repo currently uses.

`design/Privacy Policy.dc.html` is the app's privacy policy.

## Licence

Proprietary. All rights reserved, A&C Creative Company.
