# Pill Time

A medication tracker for iPhone and Android, built for someone who sometimes wakes up groggy to take a dose.

- **Flexible schedules.** Each med runs either "every X hours" or at fixed clock times.
- **Fast logging.** Tap **TAKE MEDS**, snap a photo of the pills, and tap **SAVE**. Meds that are due are already ticked.
- **Never too soon.** Each med has a minimum gap between doses. A late dose pushes the next one back automatically, and every alarm after it moves too.
- **Loud alarms.** On iPhone (iOS 26+), Pill Time sets real system alarms. On Android, it sets alarm-clock alerts that use the alarm sound, keep ringing, and show over the lock screen. If a dose still isn't logged, follow-up reminders come 10, 20 and 30 minutes later.
- **A record.** Every dose is saved with its time, photo and med list. The History screen can share the log as a spreadsheet (CSV).
- **FDA label lookup.** When you add a med, you can pull its official dosing text from the FDA's free [openFDA](https://open.fda.gov/apis/drug/label/) database and get a suggested gap. The gap is never saved until a person confirms it.

> Pill Time is a reminder and a log, not medical advice. Always follow the prescription, and check every minimum gap with a pharmacist.

## How the timing works

For each med:

| | |
|---|---|
| **Planned** | Last dose + X hours, or the next clock time after the slot the last dose covered |
| **Safe at** | Last dose + minimum gap |
| **Next due** | Whichever of the two is **later** |

- A med shows **NOT YET** in red until its safe time. If you tick it anyway, a warning shows the last dose and the safe time.
- A med is pre-ticked when it's due, or up to 20 minutes before it's due, as long as it's past its safe time.
- If clock-time doses were missed, one dose shows as due. Doses never stack up.

The rules live in `lib/core/scheduler.dart`, and `test/core_test.dart` covers them.

## Trying it on an Android phone

1. Open the repo's **Actions** tab on GitHub and click the latest green **Build** run.
2. Under **Artifacts**, download **pill-time-android** and unzip it to get `app-release.apk`.
3. Send the APK to the phone (email, Google Drive, or a USB cable) and open it there. Android will ask you to allow installing apps from that source. Allow it once.
4. Open Pill Time. Allow notifications, then on the "Alarms & reminders" screen turn the switch on, and allow full-screen alerts if asked.

## Running it on an iPhone (on Sarah's Mac)

One-time setup:

1. Install **Xcode** from the Mac App Store. Open it once and let it install its components.
2. Install Flutter: follow https://docs.flutter.dev/get-started/install/macos (the "iOS" path). Run `flutter doctor` until the iOS items are green.
3. In Xcode, open **Settings → Accounts** and sign in with the Apple ID that has the EveryPlace developer membership.
4. Clone this repo, then in Terminal run `flutter pub get` inside it.

Run it on a phone:

1. Plug in the iPhone, unlock it, and tap **Trust**. On the phone, turn on **Settings → Privacy & Security → Developer Mode** (it restarts).
2. Open `ios/Runner.xcworkspace` in Xcode. Click **Runner**, open **Signing & Capabilities**, and choose the EveryPlace team. If Xcode says the bundle ID `com.everyplace.pilltime` is taken, change it to something unique.
3. In Terminal, run `flutter run --release` and pick the phone.

Send it to Kristen with TestFlight:

1. Bump the version in `pubspec.yaml` (for example `1.0.0+2`). The number after `+` must go up with every upload.
2. Run `flutter build ipa`.
3. Open the `.xcarchive` it made (in `build/ios/archive/`) in Xcode's **Organizer**, then click **Distribute App → App Store Connect → Upload**.
4. In [App Store Connect](https://appstoreconnect.apple.com), open the app, go to **TestFlight**, and add Kristen as a tester. She installs the free TestFlight app and taps the invite.

## Project layout

```
lib/core/        Timing rules, models, gap suggestions, CSV (plain Dart, unit tested)
lib/services/    File storage, alarms and reminders, FDA lookup
lib/ui/          Screens: home, take meds, meds, edit med, FDA lookup, history
ios/Runner/AppDelegate.swift   iPhone alarm bridge (AlarmKit)
prototypes/pythonista/         The original single-file Pythonista prototype
```

Data stays on the phone, in the app's documents folder (`meds.json`, `log.json`, `photos/`). On iPhone it's also visible in the Files app under "Pill Time".
