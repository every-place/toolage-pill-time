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

## Sending builds to TestFlight (no Mac needed)

GitHub builds the iPhone app, signs it, and uploads it to TestFlight. After the one-time setup below, getting a new version onto your phone is just: **Actions → TestFlight → Run workflow**, wait about 15 minutes, then update in the TestFlight app.

### One-time setup

1. **Developer membership.** Sign in at [developer.apple.com/account](https://developer.apple.com/account) and check that the membership is active. On the same page, under **Membership details**, copy the **Team ID** (10 characters).
2. **Register the app's ID.** In **Certificates, IDs & Profiles → Identifiers**, tap **+**, choose **App IDs → App**, enter the description `Pill Time` and the explicit Bundle ID `com.everyplace.pilltime`, then tap **Continue** and **Register**.
3. **Create the app in App Store Connect.** At [appstoreconnect.apple.com](https://appstoreconnect.apple.com), go to **Apps**, tap **+**, then **New App**. Choose platform iOS and bundle ID `com.everyplace.pilltime`. The name must be unique on the App Store, so if "Pill Time" is taken, try "Pill Time by EveryPlace". Any SKU works, such as `pilltime`. Nothing becomes public; this is only the app's record.
4. **Make an API key.** In App Store Connect, open **Users and Access → Integrations → App Store Connect API**, then tap **Generate API Key**. Name it `GitHub`, give it **Admin** access (needed so GitHub can create signing certificates), and download the `.p8` file. You can only download it once. Note the **Key ID** next to it and the **Issuer ID** at the top of the page.
5. **Add four GitHub secrets.** In this repo on GitHub, open **Settings → Secrets and variables → Actions**. Add each of these with **New repository secret**:

   | Name | Value |
   |---|---|
   | `APPLE_TEAM_ID` | The Team ID from step 1 |
   | `ASC_KEY_ID` | The Key ID from step 4 |
   | `ASC_ISSUER_ID` | The Issuer ID from step 4 |
   | `ASC_KEY_P8` | The whole contents of the `.p8` file. Open it in a text editor and copy everything, including the BEGIN and END lines |

   Secrets can't be read back by anyone, including from the workflow logs.
6. **Run it.** On GitHub, open **Actions → TestFlight → Run workflow**.
7. **Install it.** When the build appears in App Store Connect under **TestFlight** (it can take 5 to 30 minutes to finish processing), create an **Internal Testing** group, add yourself, and accept the email invite on your iPhone. You install the build through the free **TestFlight** app. Add Kristen to the same group the same way.

The first time, TestFlight may ask about encryption. The app already declares that it uses none.

## Trying it on an Android phone

1. Open the repo's **Actions** tab on GitHub and click the latest green **Build** run.
2. Under **Artifacts**, download **pill-time-android** and unzip it to get `app-release.apk`.
3. Send the APK to the phone (email, Google Drive, or a USB cable) and open it there. Android will ask you to allow installing apps from that source. Allow it once.
4. Open Pill Time. Allow notifications, then on the "Alarms & reminders" screen turn the switch on, and allow full-screen alerts if asked.

## Installing free from a Mac (no developer membership)

A free Apple ID can install Pill Time on your own iPhone. The catch is that the install **expires after 7 days**. When it does, the app won't open until you plug the phone back in and run it again. Your meds and history are kept, because reinstalling over the top doesn't erase them. Just don't delete the app.

What you need: a Mac with macOS 15.6 or later (for example Sarah's), the iPhone, and a USB cable. Allow about an hour the first time, mostly downloads.

### One-time setup on the Mac

1. **Install Xcode** from the Mac App Store (it's large). Open it once, accept the license, and when it asks which platforms to install, include **iOS**.
2. **Install Flutter.** The easiest way is Homebrew. If Homebrew isn't installed, paste the command from [brew.sh](https://brew.sh) into Terminal first. Then run:
   ```
   brew install --cask flutter
   brew install cocoapods
   flutter doctor
   ```
   `flutter doctor` lists anything still missing for iOS. Fix those items, but ignore the Android ones.
3. **Sign Xcode in to your Apple ID.** In Xcode, open **Settings → Accounts → +** and add your normal Apple ID. It shows up as "(Personal Team)".
4. **Get the code.** On GitHub, open this repo, click **Code → Download ZIP**, and unzip it, for example to your Desktop. Then in Terminal:
   ```
   cd ~/Desktop/toolage-pill-time-main
   flutter pub get
   ```
5. **Choose your team.** Open `ios/Runner.xcworkspace` in Xcode. Click **Runner** in the left sidebar, then the **Runner** target, then **Signing & Capabilities**. Tick **Automatically manage signing** and set **Team** to your Personal Team. If Xcode says the bundle identifier isn't available, change it to something unique, such as `com.everyplace.pilltime.aaron`.

### Install (and again every 7 days)

1. Plug the iPhone into the Mac, unlock it, and tap **Trust** if asked.
2. First time only, on the iPhone: turn on **Settings → Privacy & Security → Developer Mode**. The phone restarts.
3. On the Mac, in Terminal, inside the project folder:
   ```
   flutter run --release
   ```
   Pick the iPhone if it asks. When it says the app is installed, you can unplug.
4. First time only, on the iPhone: if it says "Untrusted Developer", go to **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.

To refresh after 7 days, repeat steps 1 and 3. To get a newer version of the app, download the ZIP again first.

### With a developer membership

Sign Xcode in with the developer Apple ID and pick that team in step 5 instead. Installs then last a year, and the TestFlight section above becomes available.

## Project layout

```
lib/core/        Timing rules, models, gap suggestions, CSV (plain Dart, unit tested)
lib/services/    File storage, alarms and reminders, FDA lookup
lib/ui/          Screens: home, take meds, meds, edit med, FDA lookup, history
ios/Runner/AppDelegate.swift   iPhone alarm bridge (AlarmKit)
prototypes/pythonista/         The original single-file Pythonista prototype
```

Data stays on the phone, in the app's documents folder (`meds.json`, `log.json`, `photos/`). On iPhone it's also visible in the Files app under "Pill Time".
