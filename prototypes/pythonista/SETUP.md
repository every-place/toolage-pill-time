# Med Tracker setup (Pythonista prototype)

## 1. Install the script
1. Install **Pythonista 3** from the App Store.
2. In Pythonista, tap **+**, choose **Empty Script**, and name it `med_tracker.py`. Save it at the top level of "This iPhone".
3. Paste in the contents of `med_tracker.py` and tap ▶ Run.
4. Optional: to get a one-tap home screen icon, open the wrench menu (🔧) and choose **Shortcuts… → Home Screen**.

The first run creates a `MedTrackerData` folder next to the script, holding sample meds, the log, the CSV and the photos.

## 2. Add the real meds
Tap **Meds**, then **+ Add a med**:
- Type the name. You can look it up in the FDA label database (openFDA). The app shows the label's dosing text and suggests a minimum gap.
- Pick **every X hours** or **fixed clock times** (for example `08:00, 20:00`).
- Set the **minimum gap**. Before saving, the app asks you to confirm "Minimum time between doses of X is Y". It does this every time a gap is set or changed.
- Delete the two example meds.

## 3. Turn on loud Clock alarms (recommended)
Notifications work out of the box, with three follow-up nags. To also get a real alarm that rings through silent mode:

1. In the **Shortcuts** app, create a shortcut named exactly **Med Alarm**.
2. Under the shortcut's details (ⓘ), allow it to receive **Text**.
3. Add **Get Dates from Input** and point it at *Shortcut Input*.
4. To clear old alarms: add **Get All Alarms**, filter where Label is `Med dose`, then **Toggle Alarm → Off**. Action names vary a bit between iOS versions.
5. Add **Create Alarm**. Set Time = *Dates* and Label = `Med dose`.
6. Back in Med Tracker, open **Meds → Settings** and turn on **Also set a Clock alarm**.

After each saved dose, the app briefly jumps to Shortcuts to set the next alarm.

## How the timing works
- Each med has a planned next time (last dose + X hours, or the next clock slot) and a **safe time** (last dose + minimum gap).
- The next due time is whichever is **later**, so a late dose pushes the next one back automatically.
- Before the safe time, the med shows **NOT YET** in red. If she ticks it anyway, she gets a warning naming the last dose and the safe time.
- A med is pre-ticked when it's due, or up to 20 minutes before it's due.

This app helps her remember. It is not medical advice. Check every minimum gap against the prescription label or with a pharmacist.
