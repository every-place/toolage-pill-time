# Med Tracker: a Pythonista 3 prototype for fast, safe dose logging.
#
# One file. Copy it into Pythonista and tap Run.
# Data is stored in a "MedTrackerData" folder next to this script:
#   meds.json   your med list (edit it in the app)
#   log.jsonl   one line per logged dose
#   log.csv     the same log, ready to open in Numbers or Excel
#   photos/     one photo per dose
#
# The schedule logic (top half) is plain Python and runs anywhere, so it can
# be tested on a computer. Pythonista-only modules are imported in the UI part.

import csv
import datetime as dt
import json
import os
import re
import uuid

DATA_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'MedTrackerData')

# How early a med counts as "due" (and is pre-checked) before its planned time.
DUE_WINDOW_MIN = 20
# Follow-up nags after a dose is due, in minutes, for a groggy user.
NAG_MINUTES = (5, 10, 20)
# Name of the iOS Shortcut that sets a real Clock alarm (see SETUP.md).
ALARM_SHORTCUT = 'Med Alarm'

TIME_FMT = '%Y-%m-%dT%H:%M:%S'

SAMPLE_MEDS = [
    {
        'name': 'Example med (every 6 hours)',
        'schedule': {'type': 'interval', 'hours': 6},
        'min_gap_min': 300,
        'gap_confirmed': False,
        'active': True,
    },
    {
        'name': 'Example med (8 AM and 8 PM)',
        'schedule': {'type': 'times', 'times': ['08:00', '20:00']},
        'min_gap_min': 600,
        'gap_confirmed': False,
        'active': True,
    },
]


# ----------------------------------------------------------------------------
# Storage
# ----------------------------------------------------------------------------

class Store(object):
    def __init__(self, data_dir=DATA_DIR):
        self.dir = data_dir
        self.photo_dir = os.path.join(data_dir, 'photos')
        self.meds_path = os.path.join(data_dir, 'meds.json')
        self.log_path = os.path.join(data_dir, 'log.jsonl')
        self.csv_path = os.path.join(data_dir, 'log.csv')
        if not os.path.isdir(self.photo_dir):
            os.makedirs(self.photo_dir)

    def load_meds(self):
        if not os.path.exists(self.meds_path):
            self.save_meds(SAMPLE_MEDS)
        with open(self.meds_path) as f:
            return json.load(f)

    def save_meds(self, meds):
        tmp = self.meds_path + '.tmp'
        with open(tmp, 'w') as f:
            json.dump(meds, f, indent=2)
        os.replace(tmp, self.meds_path)

    def load_log(self):
        entries = []
        if os.path.exists(self.log_path):
            with open(self.log_path) as f:
                for line in f:
                    line = line.strip()
                    if line:
                        entries.append(json.loads(line))
        entries.sort(key=lambda e: e['time'])
        return entries

    def add_entry(self, taken_at, med_names, photo_file=None, note=''):
        entry = {
            'id': uuid.uuid4().hex[:12],
            'time': taken_at.strftime(TIME_FMT),
            'meds': list(med_names),
            'photo': photo_file,
            'note': note,
        }
        with open(self.log_path, 'a') as f:
            f.write(json.dumps(entry) + '\n')
        self.write_csv()
        return entry

    def write_csv(self):
        with open(self.csv_path, 'w', newline='') as f:
            w = csv.writer(f)
            w.writerow(['date', 'time', 'meds', 'photo', 'note'])
            for e in self.load_log():
                t = parse_time(e['time'])
                w.writerow([t.strftime('%Y-%m-%d'), t.strftime('%H:%M'),
                            '; '.join(e['meds']), e.get('photo') or '',
                            e.get('note', '')])


def parse_time(s):
    return dt.datetime.strptime(s, TIME_FMT)


# ----------------------------------------------------------------------------
# Schedule logic
# ----------------------------------------------------------------------------

def last_taken(med_name, log):
    """Most recent time this med was logged, or None."""
    for e in reversed(log):
        if med_name in e['meds']:
            return parse_time(e['time'])
    return None


def _slots_around(times, start_day, days):
    """All fixed-time slots from start_day for `days` days, sorted."""
    out = []
    for d in range(days):
        day = start_day + dt.timedelta(days=d)
        for hhmm in times:
            h, m = [int(x) for x in hhmm.split(':')]
            out.append(dt.datetime(day.year, day.month, day.day, h, m))
    return sorted(out)


def planned_next(med, last, now):
    """When the next dose is planned, ignoring the safety gap."""
    sched = med['schedule']
    if sched['type'] == 'interval':
        if last is None:
            return now
        return last + dt.timedelta(hours=float(sched['hours']))

    if sched['type'] == 'times':
        times = sched['times']
        if not times:
            return None
        if last is None:
            # Never taken: the most recent slot today counts as due now,
            # otherwise the first slot of the day.
            slots = _slots_around(times, now.date() - dt.timedelta(days=1), 3)
            past = [s for s in slots if s <= now and s.date() == now.date()]
            return past[-1] if past else [s for s in slots if s > now][0]
        # The last dose "covers" the slot nearest to it; next is the slot after.
        slots = _slots_around(times, last.date() - dt.timedelta(days=1), 3)
        covered = min(slots, key=lambda s: abs((s - last).total_seconds()))
        later = [s for s in slots if s > covered]
        # If several slots were missed this is simply in the past, so one
        # dose shows as due now. Doses never stack up.
        return later[0]

    raise ValueError('Unknown schedule type: %r' % sched['type'])


def med_status(med, log, now):
    """Everything the screen needs to know about one med right now."""
    last = last_taken(med['name'], log)
    gap = dt.timedelta(minutes=int(med.get('min_gap_min') or 0))
    safe_at = last + gap if last else None
    planned = planned_next(med, last, now)
    if planned is None:
        next_due = safe_at
    elif safe_at is None:
        next_due = planned
    else:
        # The key rule: a late dose pushes the next one back so it is never
        # sooner than the minimum gap.
        next_due = max(planned, safe_at)

    too_early = safe_at is not None and now < safe_at
    due = (not too_early) and next_due is not None and \
        now >= next_due - dt.timedelta(minutes=DUE_WINDOW_MIN)
    shifted = planned is not None and safe_at is not None and safe_at > planned
    return {
        'name': med['name'],
        'last': last,
        'safe_at': safe_at,
        'planned': planned,
        'next_due': next_due,
        'too_early': too_early,
        'due': due,
        'shifted': shifted,
        'gap_confirmed': bool(med.get('gap_confirmed')),
    }


def all_status(meds, log, now):
    rows = [med_status(m, log, now) for m in meds if m.get('active', True)]
    rows.sort(key=lambda r: (not r['due'], r['next_due'] or dt.datetime.max))
    return rows


def upcoming_alerts(statuses, now, horizon_hours=36):
    """Group upcoming due times (within 5 min of each other) into alerts."""
    times = sorted((s['next_due'], s['name']) for s in statuses
                   if s['next_due'] and s['next_due'] > now and
                   s['next_due'] < now + dt.timedelta(hours=horizon_hours))
    groups = []
    for t, name in times:
        if groups and (t - groups[-1][0]) <= dt.timedelta(minutes=5):
            groups[-1][1].append(name)
        else:
            groups.append((t, [name]))
    return groups


def fmt_time(t, now=None):
    if t is None:
        return '-'
    now = now or dt.datetime.now()
    clock = t.strftime('%I:%M %p').lstrip('0')
    if t.date() == now.date():
        return clock
    if t.date() == (now + dt.timedelta(days=1)).date():
        return 'tomorrow ' + clock
    if t.date() == (now - dt.timedelta(days=1)).date():
        return 'yesterday ' + clock
    return t.strftime('%a ') + clock


def fmt_gap(minutes):
    h, m = divmod(int(minutes), 60)
    if h and m:
        return '%d hr %d min' % (h, m)
    if h:
        return '%d hr' % h
    return '%d min' % m


# ----------------------------------------------------------------------------
# openFDA lookup (label text only; the user always confirms the gap)
# ----------------------------------------------------------------------------

FDA_URL = 'https://api.fda.gov/drug/label.json'

_WORDS = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
          'eight': 8, 'twelve': 12, 'twenty-four': 24}
_PER_DAY = [
    (r'\bonce (?:a |per )?da(?:y|ily)\b|\bonce daily\b', 24),
    (r'\btwice (?:a |per )?da(?:y|ily)\b|\btwo times (?:a |per )?day\b', 12),
    (r'\bthree times (?:a |per )?day\b|\bthree times daily\b', 8),
    (r'\bfour times (?:a |per )?day\b|\bfour times daily\b', 6),
]


def suggest_gap_from_text(text):
    """Guess a minimum gap (minutes) from label wording.

    Returns (minutes, matched phrase) or (None, None). This is only a hint
    shown to the user; it is never saved without their confirmation.
    """
    if not text:
        return None, None
    t = text.lower()
    num = r'(\d+(?:\.\d+)?|%s)' % '|'.join(_WORDS)
    m = re.search(r'every\s+' + num + r'(?:\s*(?:to|-|or)\s*' + num +
                  r')?\s*(?:hours|hrs|hour)', t)
    if m:
        low = m.group(1)
        hours = float(_WORDS.get(low, low))
        return int(hours * 60), m.group(0)
    for pat, hours in _PER_DAY:
        m = re.search(pat, t)
        if m:
            return hours * 60, m.group(0)
    return None, None


def fda_search(name, limit=5):
    """Look up a drug label by brand or generic name. Needs network."""
    import requests
    q = name.strip().replace('"', '')
    search = 'openfda.brand_name:"%s"+openfda.generic_name:"%s"' % (q, q)
    r = requests.get(FDA_URL + '?search=' + search.replace(' ', '+') +
                     '&limit=%d' % limit, timeout=15)
    if r.status_code == 404:
        return []
    r.raise_for_status()
    out = []
    for res in r.json().get('results', []):
        ofda = res.get('openfda', {})
        text = (res.get('dosage_and_administration') or
                res.get('directions') or [''])[0]
        out.append({
            'brand': ', '.join(ofda.get('brand_name', [])) or '?',
            'generic': ', '.join(ofda.get('generic_name', [])) or '?',
            'route': ', '.join(ofda.get('route', [])),
            'text': text.strip(),
        })
    return out


# ----------------------------------------------------------------------------
# Pythonista UI
# ----------------------------------------------------------------------------

GREEN = '#1b8a3a'
RED = '#c62828'
GREY = '#666666'
AMBER = '#b26a00'


def run_app():
    import console
    import dialogs
    import notification
    import photos
    import ui
    import webbrowser
    try:
        from urllib.parse import quote
    except ImportError:
        from urllib import quote

    store = Store()

    def now():
        return dt.datetime.now().replace(microsecond=0)

    # ---- alarms and notifications -------------------------------------

    def reschedule_alerts(statuses, set_clock_alarm):
        notification.cancel_all()
        n = now()
        groups = upcoming_alerts(statuses, n)
        script_url = 'pythonista3://' + quote(os.path.basename(__file__)) + \
            '?action=run'
        for t, names in groups[:12]:
            delay = (t - n).total_seconds()
            msg = 'Time for: ' + ', '.join(names)
            notification.schedule(msg, delay=delay, sound_name='digital:Alarm1',
                                  action_url=script_url)
            for extra in NAG_MINUTES:
                notification.schedule('Still waiting: ' + ', '.join(names),
                                      delay=delay + extra * 60,
                                      sound_name='digital:Alarm1',
                                      action_url=script_url)
        if set_clock_alarm and groups:
            t = groups[0][0]
            url = ('shortcuts://run-shortcut?name=' + quote(ALARM_SHORTCUT) +
                   '&input=text&text=' + quote(t.strftime('%Y-%m-%d %H:%M')))
            webbrowser.open(url)

    # ---- dose screen --------------------------------------------------

    class DoseList(object):
        """Checklist of meds for one dose."""

        def __init__(self, statuses):
            self.rows = statuses
            self.checked = set(s['name'] for s in statuses if s['due'])

        def tableview_number_of_rows(self, tv, section):
            return len(self.rows)

        def tableview_cell_for_row(self, tv, section, row):
            s = self.rows[row]
            cell = ui.TableViewCell('subtitle')
            cell.text_label.text = s['name']
            cell.text_label.font = ('<system-bold>', 22)
            if s['too_early']:
                cell.detail_text_label.text = 'TOO EARLY - safe at ' + \
                    fmt_time(s['safe_at'])
                cell.detail_text_label.text_color = RED
            elif s['due']:
                cell.detail_text_label.text = 'Due now'
                cell.detail_text_label.text_color = GREEN
            else:
                cell.detail_text_label.text = 'Not due until ' + \
                    fmt_time(s['next_due'])
                cell.detail_text_label.text_color = GREY
            cell.detail_text_label.font = ('<system>', 16)
            cell.accessory_type = 'checkmark' if s['name'] in self.checked \
                else 'none'
            return cell

        @ui.in_background
        def tableview_did_select(self, tv, section, row):
            s = self.rows[row]
            if s['name'] in self.checked:
                self.checked.discard(s['name'])
            else:
                if s['too_early']:
                    try:
                        console.alert(
                            'Too early for ' + s['name'],
                            'Last dose: %s.\nMinimum gap: %s.\nSafe at: %s.' % (
                                fmt_time(s['last']),
                                fmt_gap((s['safe_at'] - s['last'])
                                        .total_seconds() // 60),
                                fmt_time(s['safe_at'])),
                            'I already took it, log it', hide_cancel_button=False)
                    except KeyboardInterrupt:
                        return
                self.checked.add(s['name'])
            tv.reload()

    def take_dose(sender):
        _take_dose()

    @ui.in_background
    def _take_dose():
        log = store.load_log()
        meds = store.load_meds()
        statuses = all_status(meds, log, now())
        if not any(s['due'] for s in statuses):
            nxt = [s for s in statuses if s['next_due']]
            msg = 'Next: %s at %s' % (nxt[0]['name'], fmt_time(nxt[0]['next_due'])) \
                if nxt else 'Nothing scheduled.'
            try:
                console.alert('Nothing is due yet', msg, 'Log a dose anyway',
                              hide_cancel_button=False)
            except KeyboardInterrupt:
                return

        img = photos.capture_image()
        taken_at = now()
        photo_file = None
        if img is not None:
            photo_file = taken_at.strftime('%Y%m%d-%H%M%S') + '.jpg'
            img = img.convert('RGB')
            img.thumbnail((1600, 1600))
            img.save(os.path.join(store.photo_dir, photo_file), quality=80)

        lst = DoseList(statuses)
        v = ui.View(name='What did you take?', background_color='white')
        tv = ui.TableView(frame=(0, 0, 400, 400), flex='WH')
        tv.row_height = 72
        tv.data_source = tv.delegate = lst
        v.add_subview(tv)
        result = {'saved': False}

        def save(sender):
            if not lst.checked:
                console.hud_alert('Tick at least one med', 'error')
                return
            result['saved'] = True
            v.close()

        save_btn = ui.ButtonItem(title='SAVE', action=save, tint_color=GREEN)
        v.right_button_items = [save_btn]
        v.present('fullscreen')
        v.wait_modal()

        if not result['saved']:
            if photo_file:
                os.remove(os.path.join(store.photo_dir, photo_file))
            console.hud_alert('Not saved')
            refresh()
            return
        names = [s['name'] for s in statuses if s['name'] in lst.checked]
        store.add_entry(taken_at, names, photo_file)
        new_status = all_status(meds, store.load_log(), now())
        console.hud_alert('Saved %s' % fmt_time(taken_at), 'success', 1.5)
        refresh()
        reschedule_alerts(new_status, settings().get('clock_alarm', False))

    # ---- med management -----------------------------------------------

    def settings():
        p = os.path.join(store.dir, 'settings.json')
        if os.path.exists(p):
            with open(p) as f:
                return json.load(f)
        return {}

    def save_settings(s):
        with open(os.path.join(store.dir, 'settings.json'), 'w') as f:
            json.dump(s, f, indent=2)

    def lookup_fda(name):
        """Returns (label_text, suggested_gap_min, phrase) or Nones."""
        console.show_activity('Searching FDA labels...')
        try:
            results = fda_search(name)
        except Exception as e:
            console.hide_activity()
            console.alert('FDA lookup failed', str(e), 'OK',
                          hide_cancel_button=True)
            return None, None, None
        console.hide_activity()
        if not results:
            console.alert('No FDA label found', 'Try the generic name.', 'OK',
                          hide_cancel_button=True)
            return None, None, None
        items = ['%s (%s) %s' % (r['brand'], r['generic'], r['route'])
                 for r in results]
        pick = dialogs.list_dialog('Which one?', items)
        if pick is None:
            return None, None, None
        r = results[items.index(pick)]
        gap, phrase = suggest_gap_from_text(r['text'])
        header = 'FDA label dosing text (for reference only).\n'
        if gap:
            header += 'Suggested minimum gap: %s, from the words "%s".\n' % (
                fmt_gap(gap), phrase)
        else:
            header += 'No clear interval found in the text.\n'
        header += 'Always follow the prescription and your pharmacist.\n\n'
        dialogs.text_dialog('FDA label', header + r['text'])
        return r['text'], gap, phrase

    def edit_med(med=None):
        """Add or edit a med. Returns the med dict or None if cancelled."""
        is_new = med is None
        med = dict(med or {'name': '', 'schedule': {'type': 'interval',
                                                    'hours': 6},
                           'min_gap_min': 0, 'gap_confirmed': False,
                           'active': True})
        if is_new:
            name = dialogs.input_alert('Med name', 'Brand or generic name')
            if not name:
                return None
            med['name'] = name.strip()
            suggested = None
            try:
                console.alert('Look up in FDA database?',
                              'Shows the official label dosing text and a '
                              'suggested minimum gap.', 'Look up',
                              hide_cancel_button=False)
                _, suggested, _ = lookup_fda(med['name'])
            except KeyboardInterrupt:
                pass
            if suggested:
                med['min_gap_min'] = suggested
            if med['schedule']['type'] == 'interval' and suggested:
                med['schedule']['hours'] = suggested / 60.0

        sched = med['schedule']
        fields = [
            {'type': 'text', 'key': 'name', 'title': 'Name',
             'value': med['name']},
            {'type': 'switch', 'key': 'use_times',
             'title': 'Fixed clock times (off = every X hours)',
             'value': sched['type'] == 'times'},
            {'type': 'number', 'key': 'hours', 'title': 'Every X hours',
             'value': str(sched.get('hours', ''))},
            {'type': 'text', 'key': 'times',
             'title': 'Clock times (e.g. 08:00, 20:00)',
             'value': ', '.join(sched.get('times', []))},
            {'type': 'number', 'key': 'gap_h', 'title': 'Min gap: hours',
             'value': str(int(med['min_gap_min']) // 60)},
            {'type': 'number', 'key': 'gap_m', 'title': 'Min gap: minutes',
             'value': str(int(med['min_gap_min']) % 60)},
            {'type': 'switch', 'key': 'active', 'title': 'Active',
             'value': med.get('active', True)},
        ]
        r = dialogs.form_dialog('Med details', fields=fields)
        if r is None:
            return None
        try:
            med['name'] = r['name'].strip()
            if r['use_times']:
                times = [t.strip() for t in r['times'].split(',') if t.strip()]
                for t in times:
                    dt.datetime.strptime(t, '%H:%M')
                med['schedule'] = {'type': 'times', 'times': times}
            else:
                med['schedule'] = {'type': 'interval',
                                   'hours': float(r['hours'])}
            gap = int(float(r['gap_h'] or 0) * 60 + float(r['gap_m'] or 0))
        except ValueError:
            console.alert('Check the numbers and times', 'Times look like 08:00.',
                          'OK', hide_cancel_button=True)
            return None
        med['active'] = r['active']

        # The safety step: the gap must be confirmed explicitly every time
        # it is set or changed.
        if gap <= 0:
            console.alert('A minimum gap is required', '', 'OK',
                          hide_cancel_button=True)
            return None
        try:
            console.alert('Confirm minimum gap',
                          'Minimum time between doses of %s is %s.\n\n'
                          'Check this against the prescription label.' % (
                              med['name'], fmt_gap(gap)),
                          'Yes, %s is correct' % fmt_gap(gap),
                          hide_cancel_button=False)
        except KeyboardInterrupt:
            return None
        med['min_gap_min'] = gap
        med['gap_confirmed'] = True
        return med

    def manage_meds(sender):
        _manage_meds()

    @ui.in_background
    def _manage_meds():
        while True:
            meds = store.load_meds()
            items = ['+ Add a med'] + [
                '%s%s' % (m['name'], '' if m.get('active', True) else ' (off)')
                for m in meds] + ['Settings']
            pick = dialogs.list_dialog('Meds', items)
            if pick is None:
                break
            i = items.index(pick)
            if i == 0:
                m = edit_med()
                if m:
                    meds.append(m)
            elif pick == 'Settings':
                s = settings()
                r = dialogs.form_dialog('Settings', fields=[
                    {'type': 'switch', 'key': 'clock_alarm',
                     'title': 'Also set a Clock alarm (needs the "%s" '
                              'shortcut)' % ALARM_SHORTCUT,
                     'value': s.get('clock_alarm', False)}])
                if r:
                    s.update(r)
                    save_settings(s)
                continue
            else:
                old = meds[i - 1]
                try:
                    choice = console.alert(old['name'], '', 'Edit', 'Delete',
                                           hide_cancel_button=False)
                except KeyboardInterrupt:
                    continue
                if choice == 1:
                    m = edit_med(old)
                    if m:
                        meds[i - 1] = m
                else:
                    try:
                        console.alert('Delete %s?' % old['name'],
                                      'Past log entries are kept.', 'Delete',
                                      hide_cancel_button=False)
                        meds.pop(i - 1)
                    except KeyboardInterrupt:
                        pass
            store.save_meds(meds)
        refresh()
        reschedule_alerts(all_status(store.load_meds(), store.load_log(), now()),
                          False)

    # ---- history ------------------------------------------------------

    def show_history(sender):
        log = list(reversed(store.load_log()))
        if not log:
            console.hud_alert('No doses logged yet')
            return
        n = now()
        items = [{'title': '%s   %s%s' % (fmt_time(parse_time(e['time']), n),
                                             ', '.join(e['meds']),
                                             '' if e.get('photo') else ' (no photo)'),
                  'entry': e} for e in log]
        ds = ui.ListDataSource(items)

        def tapped(ds_):
            e = ds_.items[ds_.selected_row]['entry']
            if not e.get('photo'):
                console.hud_alert('No photo for this dose')
                return
            path = os.path.join(store.photo_dir, e['photo'])
            pv = ui.ImageView(frame=(0, 0, 400, 600), content_mode=ui.CONTENT_SCALE_ASPECT_FIT,
                              background_color='black')
            pv.image = ui.Image.named(path)
            pv.name = fmt_time(parse_time(e['time']), n)
            pv.present('fullscreen')

        ds.action = tapped
        tv = ui.TableView(name='History (log.csv is in MedTrackerData)')
        tv.data_source = tv.delegate = ds
        tv.row_height = 60
        tv.present('fullscreen')

    # ---- main screen --------------------------------------------------

    root = ui.View(name='Meds', background_color='white')
    status_view = ui.TextView(editable=False, selectable=False,
                              font=('<system>', 20), flex='WH')
    big = ui.Button(title='TAKE MEDS', flex='W', font=('<system-bold>', 40),
                    background_color=GREEN, tint_color='white',
                    corner_radius=24, action=take_dose)
    meds_btn = ui.Button(title='Meds', action=manage_meds,
                         font=('<system>', 20), tint_color=GREY)
    hist_btn = ui.Button(title='History', action=show_history,
                         font=('<system>', 20), tint_color=GREY)
    for sv in (status_view, big, meds_btn, hist_btn):
        root.add_subview(sv)

    def layout():
        w, h = root.width, root.height
        pad = 16
        big.frame = (pad, h * 0.55, w - 2 * pad, h * 0.30)
        status_view.frame = (pad, pad, w - 2 * pad, h * 0.55 - 2 * pad)
        meds_btn.frame = (pad, h * 0.88, (w - 3 * pad) / 2, 50)
        hist_btn.frame = (2 * pad + (w - 3 * pad) / 2, h * 0.88,
                          (w - 3 * pad) / 2, 50)

    root.layout = layout

    def refresh():
        n = now()
        statuses = all_status(store.load_meds(), store.load_log(), n)
        lines = []
        for s in statuses:
            if s['too_early']:
                state = 'NOT YET. Safe at %s' % fmt_time(s['safe_at'], n)
            elif s['due']:
                state = 'DUE NOW'
            else:
                state = 'Next: %s' % fmt_time(s['next_due'], n)
            if s['shifted'] and not s['due']:
                state += ' (moved later)'
            extra = '' if s['gap_confirmed'] else \
                '\n   ! Minimum gap not confirmed: tap Meds'
            lines.append('%s\n   %s\n   Last: %s%s' % (
                s['name'], state, fmt_time(s['last'], n), extra))
        status_view.text = '\n\n'.join(lines) or 'Tap Meds to add your meds.'
        due = any(s['due'] for s in statuses)
        big.background_color = GREEN if due else '#9e9e9e'
        big.title = 'TAKE MEDS' if due else 'TAKE MEDS (none due)'

    refresh()
    root.present('fullscreen', hide_title_bar=False)
    layout()

    # Keep the screen current while it is open.
    import threading

    def tick():
        if root.on_screen:
            refresh()
            threading.Timer(30, tick).start()

    threading.Timer(30, tick).start()


if __name__ == '__main__':
    run_app()
