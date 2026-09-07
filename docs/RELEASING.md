# Releasing

Distribution is a signed APK attached to a GitHub Release. No Play Console fee,
no review, no subscription billing.

## One-time setup

### 1. Create the upload keystore

```
keytool -genkey -v -keystore prakriya-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep this file and its passwords forever. A different key on a later version
forces every user to uninstall and lose their data. Back it up offline and store
the passwords in a password manager. It is gitignored — never commit it.

### 2. Point Gradle at it

Create `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../prakriya-upload.jks
```

Then wire the release `signingConfig` in `android/app/build.gradle` to read it.

### 3. Add the repository secrets

For the automated build, in Settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `KEYSTORE_BASE64` | `base64 -i prakriya-upload.jks` output |
| `KEYSTORE_PASSWORD` | store password |
| `KEY_PASSWORD` | key password |
| `KEY_ALIAS` | `upload` |

## App rename (Ritualist → Prakriyā)

The rename (Dart package name, Android applicationId
`ai.aandccreative.ritualist` → `ai.aandccreative.prakriya`, storage keys,
notification channel, GitHub Releases check, Firebase setup) is complete.

1. **Firebase**: done. A second Android app (`ai.aandccreative.prakriya`,
   alongside the untouched original `ai.aandccreative.ritualist` entry) is
   registered in the `prakriya-82d0e` Firebase project, with the upload
   keystore's SHA-1 and SHA-256 fingerprints added, Google as an enabled
   Auth sign-in provider, and a live Firestore database with rules matching
   `firestore.rules`. `android_overrides/google-services.json` holds the
   real config downloaded from the console. If the upload keystore is ever
   rotated, the new fingerprints need adding to that same app card and a
   fresh `google-services.json` pulled down.
2. **GitHub repo name**: done — the repo is now
   `aandccreativecompany-dev/Prakriya`. `lib/services/update_checker.dart`'s
   `_repo` constant and the link below are already updated to match.
   Update your local `origin` remote if you haven't:
   `git remote set-url origin
   https://github.com/aandccreativecompany-dev/Prakriya.git`
3. **Existing installs**: because the applicationId changed, Android treats
   this as a different app — anyone with the old Ritualist APK installed
   will not get this as an "update"; they need to install the new APK
   alongside or after uninstalling the old one. Anyone signed in gets their
   data back automatically via cloud backup; local-only data on the old
   install does not carry over. Worth saying plainly in the release notes.

## Cutting a release

1. Merge `dev` into `main`.
2. Bump `version:` in `pubspec.yaml` — the build number after `+` must increase
   every single time.
3. Tag and push:

```
git tag v0.1.0
git push origin v0.1.0
```

The `release.yml` workflow builds the signed APK and attaches it to a draft
release. Open the release, write the notes, publish.

The permanent link to hand to users:
`https://github.com/aandccreativecompany-dev/Prakriya/releases/latest`

## Release notes template

```
## What's new
- ...

## Install
1. Download the APK below.
2. When your phone asks, allow installs from this source.
3. If a screen says the app is unrecognised or unsafe, tap
   More details → Install anyway. This warning is normal for apps
   installed outside the Play Store.
4. Open Prakriyā and allow notifications so your reminders arrive.

Want automatic updates? Install Obtainium, point it at this repository once,
and it will update Prakriyā for you.
```

Expect to lose people at the Play Protect warning. Saying up front that it is
normal recovers a good share of them.

## Manual build, if the workflow is not set up yet

```
flutter build apk --release
```

Output at `build/app/outputs/flutter-apk/app-release.apk`. Rename it
`prakriya-0.1.0.apk` before attaching, so the version is visible in the download.
