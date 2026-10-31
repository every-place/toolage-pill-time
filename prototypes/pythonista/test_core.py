import sys, datetime as dt, tempfile
sys.path.insert(0, '/mnt/project-files/med-tracker')
import med_tracker as m
D = dt.datetime
def log(*items): return [{'time': t.strftime(m.TIME_FMT), 'meds': n} for t, n in items]
iv = {'name': 'A', 'schedule': {'type': 'interval', 'hours': 6}, 'min_gap_min': 300, 'gap_confirmed': True}
tm = {'name': 'B', 'schedule': {'type': 'times', 'times': ['08:00', '20:00']}, 'min_gap_min': 600}

def test_interval_delay_shifts():
    s = m.med_status(iv, log((D(2026,1,1,2,0), ['A'])), D(2026,1,1,4,0))
    assert s['too_early'] and s['safe_at'] == D(2026,1,1,7,0) and s['next_due'] == D(2026,1,1,8,0)
    s = m.med_status(iv, log((D(2026,1,1,5,30), ['A'])), D(2026,1,1,6,0))
    assert s['next_due'] == D(2026,1,1,11,30)

def test_never_taken_due():
    assert m.med_status(iv, [], D(2026,1,1,3,0))['due']

def test_times_late_dose_pushes_next():
    # 8 AM dose taken at 11 AM -> 8 PM slot pushed to 9 PM (10h gap)
    s = m.med_status(tm, log((D(2026,1,1,11,0), ['B'])), D(2026,1,1,12,0))
    assert s['planned'] == D(2026,1,1,20,0) and s['next_due'] == D(2026,1,1,21,0) and s['shifted']
    s = m.med_status(tm, log((D(2026,1,1,11,0), ['B'])), D(2026,1,1,20,30))
    assert s['too_early'] and not s['due']
    s = m.med_status(tm, log((D(2026,1,1,11,0), ['B'])), D(2026,1,1,21,0))
    assert s['due']

def test_times_early_dose_covers_slot():
    s = m.med_status(tm, log((D(2026,1,1,7,50), ['B'])), D(2026,1,1,8,5))
    assert s['planned'] == D(2026,1,1,20,0) and not s['due']

def test_times_evening_rolls_to_tomorrow():
    s = m.med_status(tm, log((D(2026,1,1,20,10), ['B'])), D(2026,1,1,23,0))
    assert s['next_due'] == D(2026,1,2,8,0)

def test_due_window():
    s = m.med_status(iv, log((D(2026,1,1,0,0), ['A'])), D(2026,1,1,5,45))
    assert s['due']  # within 20 min of 6:00 and past 5h gap
    s = m.med_status(iv, log((D(2026,1,1,0,0), ['A'])), D(2026,1,1,5,30))
    assert not s['due']

def test_gap_text():
    assert m.suggest_gap_from_text('Take 1 tablet every 4 to 6 hours while symptoms persist')[0] == 240
    assert m.suggest_gap_from_text('one tablet every twelve hours')[0] == 720
    assert m.suggest_gap_from_text('Administer twice daily with food')[0] == 720
    assert m.suggest_gap_from_text('Take once daily')[0] == 1440
    assert m.suggest_gap_from_text('as directed by physician') == (None, None)

def test_store_roundtrip():
    st = m.Store(tempfile.mkdtemp())
    assert st.load_meds() == m.SAMPLE_MEDS
    st.add_entry(D(2026,1,1,3,0), ['A', 'B'], 'x.jpg')
    assert st.load_log()[0]['meds'] == ['A', 'B']
    assert 'A; B' in open(st.csv_path).read()

def test_alert_grouping():
    now = D(2026,1,1,0,0)
    st = [{'name':'A','next_due':D(2026,1,1,6,0)},{'name':'B','next_due':D(2026,1,1,6,3)},{'name':'C','next_due':D(2026,1,1,9,0)}]
    g = m.upcoming_alerts(st, now)
    assert g == [(D(2026,1,1,6,0), ['A','B']), (D(2026,1,1,9,0), ['C'])]
