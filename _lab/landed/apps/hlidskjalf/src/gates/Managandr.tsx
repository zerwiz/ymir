import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { StatusChip } from '../components/Status';
import { MetricTile } from '../components/MetricTile';
import { gateApi, type CalendarEvent, type SmidjaDetail, type SmidjaPhase } from '../services/api';

/**
 * Mánagandr — the read calendar (plan 60, amendment 2026-09-29). The Allfather
 * sealed the shape: a month grid with week columns and hour rows, a now line on
 * today's column, lane toggles, and the Nornir collision hairline. It is a
 * RECKONING: the gate reads the hoard and composes the lanes the house already
 * serves — no create, no edit, no delete, no write verb anywhere.
 *
 * UNKNOWN IS NOT EMPTY. The reader's cache is the Allfather's Phase 0 and may not
 * exist yet; a Smíðja store with no phases is not a broken grid. Each lane says
 * which of those it is, in words, in the house's register.
 */

type LaneId = 'reckoning' | 'nornir' | 'smidja' | 'well';

const LANES: { id: LaneId; label: string; glyph: string }[] = [
  { id: 'reckoning', label: 'Reckoning', glyph: 'ᛅ' },
  { id: 'nornir', label: 'Nornir', glyph: 'ᛃ' },
  { id: 'smidja', label: 'Smíðja', glyph: 'ᛋ' },
  { id: 'well', label: 'Well', glyph: 'ᛜ' },
];

const HOUR_H = 15; // px per hour row — the grid is glanceable, the read view explains
const WEEKDAYS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const HOURS = Array.from({ length: 24 }, (_, h) => h);

/* ---- time, always in the MACHINE'S zone (never a hardcoded offset) -------- */
/** A date-only string is a local day, never UTC midnight. */
function localDate(iso: string): Date {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])) : new Date(iso);
}
function startOfDay(d: Date): Date {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}
function addDays(d: Date, n: number): Date {
  const x = new Date(d);
  x.setDate(x.getDate() + n);
  return x;
}
function dayKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
function sameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}
function minutesOf(d: Date): number {
  return d.getHours() * 60 + d.getMinutes();
}
const fmtTime = (d: Date) => d.toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
const fmtDay = (d: Date) => d.toLocaleDateString(undefined, { weekday: 'short', day: 'numeric', month: 'short' });

const MACHINE_ZONE = (() => {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || 'the machine zone';
  } catch {
    return 'the machine zone';
  }
})();

function monthWeeks(year: number, month: number): Date[][] {
  const first = new Date(year, month, 1);
  const last = new Date(year, month + 1, 0);
  let cur = addDays(first, -((first.getDay() + 6) % 7)); // back to Monday
  const weeks: Date[][] = [];
  while (cur <= last || weeks.length === 0) {
    weeks.push(Array.from({ length: 7 }, (_, i) => addDays(cur, i)));
    cur = addDays(cur, 7);
    if (weeks.length >= 6) break;
  }
  return weeks;
}

/* ---- event layout: overlapping blocks share a day column ----------------- */
interface Timed {
  ev: CalendarEvent;
  startMin: number;
  endMin: number;
}
interface Laid extends Timed {
  lane: number;
  lanes: number;
}
function layoutTimed(items: Timed[]): Laid[] {
  const sorted = [...items].sort((a, b) => a.startMin - b.startMin || a.endMin - b.endMin);
  const laneEnds: number[] = [];
  const withLane = sorted.map((it) => {
    let lane = laneEnds.findIndex((end) => end <= it.startMin);
    if (lane === -1) {
      lane = laneEnds.length;
      laneEnds.push(it.endMin);
    } else {
      laneEnds[lane] = it.endMin;
    }
    return { ...it, lane };
  });
  return withLane.map((it) => {
    const overlapping = withLane.filter((o) => o.startMin < it.endMin && o.endMin > it.startMin);
    const lanes = Math.max(...overlapping.map((o) => o.lane)) + 1;
    return { ...it, lanes };
  });
}

/** The timed events of one day, clipped to that day's [0, 1440) minutes. */
function timedForDay(day: Date, events: CalendarEvent[]): Timed[] {
  const start = startOfDay(day).getTime();
  const end = start + 86_400_000;
  const out: Timed[] = [];
  for (const ev of events) {
    if (ev.allDay) continue;
    const s = localDate(ev.start);
    const e = ev.end ? localDate(ev.end) : new Date(s.getTime() + 30 * 60_000);
    if (s.getTime() >= end || e.getTime() <= start) continue;
    out.push({
      ev,
      startMin: Math.max(0, (s.getTime() - start) / 60_000),
      endMin: Math.min(1440, (e.getTime() - start) / 60_000),
    });
  }
  return out;
}
function allDayForDay(day: Date, events: CalendarEvent[]): CalendarEvent[] {
  const start = startOfDay(day).getTime();
  const end = start + 86_400_000;
  return events.filter((ev) => {
    if (!ev.allDay) return false;
    const s = localDate(ev.start);
    // An all-day end is exclusive (the day after the last), and a bare date is
    // one day — so the chip lands on exactly the days it covers.
    const e = ev.end ? localDate(ev.end) : new Date(s.getTime() + 86_400_000);
    return s.getTime() < end && e.getTime() > start;
  });
}

const calClass = (id: string): string => {
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return `mg-cal-${h % 6}`;
};

/* ---- the honest state chip (glyph + colour + the honest WORD) ------------- */
function StateChip({ tone, glyph, children }: { tone: 'ok' | 'warn' | 'danger' | 'info'; glyph: string; children: ReactNode }) {
  return (
    <span className={`status status-${tone}`}>
      <span className="dot" aria-hidden="true">{glyph}</span>
      {children}
    </span>
  );
}

/* ---- one day column: events, now line, Nornir hairlines, the lanes -------- */
interface DayColumnProps {
  day: Date;
  events: CalendarEvent[];
  hairlines: Hairline[];
  phases: LaidPhase[];
  episodes: Tick[];
  sessionRails: Rail[];
  superseded: boolean;
  isToday: boolean;
  nowMin: number;
  lanes: Set<LaneId>;
  onSelect: (ev: CalendarEvent) => void;
}
function DayColumn({ day, events, hairlines, phases, episodes, sessionRails, superseded, isToday, nowMin, lanes, onSelect }: DayColumnProps) {
  const laid = layoutTimed(timedForDay(day, events));
  const pct = (min: number) => `${(min / 1440) * 100}%`;
  return (
    <div className={`mg-day ${isToday ? 'today' : ''}`} style={{ height: 24 * HOUR_H }}>
      {lanes.has('well') && superseded ? <span className="mg-super" title="a fact was superseded on this day" /> : null}
      {lanes.has('smidja') &&
        sessionRails.map((r) => (
          <span key={r.id} className="mg-rail" style={{ top: pct(r.startMin), height: `${Math.max(2, ((r.endMin - r.startMin) / 1440) * 100)}%` }} title={r.label} />
        ))}
      {lanes.has('smidja') &&
        phases.map((p, i) => (
          <span
            key={`${p.id}-${i}`}
            className={`mg-phase ${p.refused ? 'refused' : ''} ${calClass(p.owner)}`}
            style={{ top: pct(p.startMin), height: `${Math.max(3, ((p.endMin - p.startMin) / 1440) * 100)}%` }}
            title={`${p.owner} · ${p.status ?? 'phase'}`}
          />
        ))}
      {lanes.has('reckoning') &&
        laid.map((b) => (
          <button
            key={b.ev.id + b.startMin}
            type="button"
            className={`mg-event ${calClass(b.ev.calendarId)} ${b.ev.cancelled ? 'mg-cancelled' : ''}`}
            style={{
              top: pct(b.startMin),
              height: `${Math.max(3, ((b.endMin - b.startMin) / 1440) * 100)}%`,
              left: `${(b.lane / b.lanes) * 100}%`,
              width: `${(1 / b.lanes) * 100}%`,
            }}
            title={`${fmtTime(localDate(b.ev.start))} ${b.ev.title}`}
            onClick={() => onSelect(b.ev)}
          />
        ))}
      {lanes.has('nornir') &&
        hairlines.map((h, i) => (
          <span
            key={`${h.command}-${i}`}
            className={`mg-hair ${h.state}`}
            style={{ top: pct(h.min) }}
            title={`Nornir ${h.at} · ${h.command} · ${h.state}`}
          />
        ))}
      {lanes.has('well') &&
        episodes.map((t, i) => (
          <span
            key={`${t.id}-${i}`}
            className="mg-tick"
            style={{ top: pct(t.min), opacity: 0.25 + 0.75 * t.salience }}
            title={`episode · salience ${t.salience.toFixed(2)}${t.tags.length ? ` · ${t.tags.slice(0, 3).join(', ')}` : ''}`}
          />
        ))}
      {isToday && lanes.has('reckoning') ? (
        <span className="mg-now" style={{ top: pct(nowMin) }} title={`now · ${fmtTime(new Date())}`} />
      ) : null}
    </div>
  );
}

interface Hairline {
  min: number;
  at: string;
  command: string;
  state: 'hollow' | 'filled' | 'blood';
}
interface Tick {
  id: string;
  min: number;
  salience: number;
  tags: string[];
}
interface Rail {
  id: string;
  startMin: number;
  endMin: number;
  label: string;
}
interface LaidPhase {
  id: string;
  startMin: number;
  endMin: number;
  owner: string;
  status: string | null;
  refused: boolean;
}

/* ---- the gate ------------------------------------------------------------- */
export function Managandr() {
  const calendar = useYmir((s) => s.calendar);
  const recall = useYmir((s) => s.recall);
  const mimir = useYmir((s) => s.mimir);
  const cron = useYmir((s) => s.cron);
  const seats = useYmir((s) => s.cronSeats) ?? [];
  const sessions = useYmir((s) => s.smidjaSessions);
  const smidjaDb = useYmir((s) => s.smidjaDb);
  const refreshCalendar = useYmir((s) => s.refreshCalendar);
  const { openModal } = useUI();

  // The reckoning on its own track: ask fresh when the gate opens.
  useEffect(() => {
    void refreshCalendar();
  }, [refreshCalendar]);

  const now = new Date();
  const [cursor, setCursor] = useState({ y: now.getFullYear(), m: now.getMonth() });
  const [lanes, setLanes] = useState<Set<LaneId>>(() => new Set<LaneId>(['reckoning', 'nornir', 'smidja', 'well']));
  const [details, setDetails] = useState<Record<string, SmidjaDetail>>({});

  // Phases live behind the per-session door; fetch them once per session set.
  const sessionKey = useMemo(() => sessions.map((s) => s.smidja_id).join(','), [sessions]);
  useEffect(() => {
    let alive = true;
    void (async () => {
      const out: Record<string, SmidjaDetail> = {};
      for (const s of sessions.slice(0, 24)) {
        try {
          out[s.smidja_id] = await gateApi.smidjaSession(s.smidja_id);
        } catch {
          /* a session the gate cannot detail is simply not drawn */
        }
      }
      if (alive) setDetails(out);
    })();
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sessionKey]);

  const toggle = (id: LaneId) =>
    setLanes((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });

  const weeks = useMemo(() => monthWeeks(cursor.y, cursor.m), [cursor.y, cursor.m]);
  const monthLabel = new Date(cursor.y, cursor.m, 1).toLocaleDateString(undefined, { month: 'long', year: 'numeric' });
  const monthKey = `${cursor.y}-${String(cursor.m + 1).padStart(2, '0')}`;
  const move = (delta: number) => setCursor((c) => {
    const d = new Date(c.y, c.m + delta, 1);
    return { y: d.getFullYear(), m: d.getMonth() };
  });
  const goToday = () => { const d = new Date(); setCursor({ y: d.getFullYear(), m: d.getMonth() }); };

  const events = calendar?.events ?? [];
  const state = calendar?.state ?? 'unknown';
  const stateWord = !calendar ? 'READING' : state === 'ok' ? 'OK' : state === 'unknown' ? 'UNKNOWN' : 'ABSENT';
  const stateTone: 'ok' | 'warn' | 'danger' | 'info' = !calendar ? 'info' : state === 'ok' ? 'ok' : state === 'unknown' ? 'warn' : 'info';
  // How many cached events actually fall inside the month on screen — a fresh
  // cache with nothing THIS month must not look like a broken grid.
  const monthEvents = useMemo(() => {
    const start = new Date(cursor.y, cursor.m, 1).getTime();
    const end = new Date(cursor.y, cursor.m + 1, 1).getTime();
    return events.filter((ev) => {
      const s = localDate(ev.start).getTime();
      const e0 = ev.end ? localDate(ev.end).getTime() : s + (ev.allDay ? 86_400_000 : 1_800_000);
      return s < end && e0 > start;
    }).length;
  }, [events, cursor.y, cursor.m]);
  const reckoningNote =
    !calendar
      ? 'Reading the reckoning…'
      : state === 'absent'
        ? 'The reckoning is not granted yet — the reader holds no cache (the Allfather\u2019s Phase 0 consent).'
        : state === 'unknown'
          ? 'The cache exists but cannot prove its freshness (no readable as_of, or older than the window) — treat every block as unconfirmed.'
          : events.length === 0
            ? 'The cache is fresh and the window is empty — no events booked.'
            : monthEvents === 0
              ? `The cache is fresh; no events fall in ${monthLabel} — it carries ${events.length} across the wider window.`
              : null;

  const jobs = cron?.jobs ?? [];
  const applyingJobs = jobs.filter((j) => j.applies !== false);
  const todayKey = dayKey(now);
  const nowMin = minutesOf(now);

  // The Nornir collision: a job landing on the hour inside a meeting, that day.
  // `last{}` is the loop's single latest stamp, so a run is provable only for
  // its own day; every other day draws PLANNED (hollow), never a false missed —
  // an unprovable state is not a negative one.
  function hairlinesForDay(day: Date): Hairline[] {
    if (!lanes.has('nornir')) return [];
    const timed = timedForDay(day, events);
    const key = dayKey(day);
    const out: Hairline[] = [];
    for (const j of jobs) {
      const [hh, mm] = j.at.split(':').map(Number);
      if (!Number.isFinite(hh) || !Number.isFinite(mm)) continue;
      const atMin = hh * 60 + mm;
      const inside = timed.some((t) => t.startMin <= atMin && t.endMin > atMin);
      if (!inside) continue;
      // Every scheduled firing draws the collision; the run-state is provable
      // only for a job THIS seat runs — elsewhere it stays planned, not missed.
      const mine = j.applies !== false;
      const ranOnDay = mine && (cron?.last?.[j.command] ?? '') === key;
      const missedToday = mine && key === todayKey && (atMin < nowMin || !cron?.running) && !ranOnDay;
      const state: Hairline['state'] = ranOnDay ? 'filled' : missedToday ? 'blood' : 'hollow';
      out.push({ min: atMin, at: j.at, command: j.command, state });
    }
    return out;
  }

  // Smíðja: a thin rail per session, a block per phase, a blood edge on refusal.
  function phasesForDay(day: Date): { rails: Rail[]; phases: LaidPhase[] } {
    if (!lanes.has('smidja')) return { rails: [], phases: [] };
    const start = startOfDay(day).getTime();
    const end = start + 86_400_000;
    const rails: Rail[] = [];
    const phases: LaidPhase[] = [];
    for (const s of sessions) {
      if (!s.started_at) continue;
      const ss = new Date(s.started_at);
      const se = s.ended_at ? new Date(s.ended_at) : new Date();
      if (!Number.isFinite(ss.getTime()) || ss.getTime() >= end || se.getTime() <= start) continue;
      const startMin = Math.max(0, (ss.getTime() - start) / 60_000);
      const endMin = Math.min(1440, (se.getTime() - start) / 60_000);
      rails.push({ id: s.smidja_id, startMin, endMin, label: `${s.smidja_name ?? s.smidja_id} · ${s.status ?? 'run'}` });
      const detail = details[s.smidja_id];
      for (const p of detail?.phases ?? []) {
        if (!p.started_at) continue;
        const ps = new Date(p.started_at);
        const pe = p.ended_at ? new Date(p.ended_at) : new Date();
        if (!Number.isFinite(ps.getTime()) || ps.getTime() >= end || pe.getTime() <= start) continue;
        phases.push({
          id: p.phase_id,
          startMin: Math.max(0, (ps.getTime() - start) / 60_000),
          endMin: Math.min(1440, (pe.getTime() - start) / 60_000),
          owner: p.owner ?? 'smith',
          status: p.status,
          refused: p.status === 'fail' || Number(p.attempt ?? 0) > 0,
        });
      }
    }
    return { rails, phases };
  }

  // The well: density, not blocks — one tick per episode, brightness by salience.
  function episodesForDay(day: Date): Tick[] {
    if (!lanes.has('well')) return [];
    const key = dayKey(day);
    return recall
      .filter((e) => e.ts && e.ts.slice(0, 10) === key)
      .map((e) => {
        const d = new Date(e.ts);
        const min = Number.isFinite(d.getTime()) ? minutesOf(d) : 0;
        return { id: e.id, min, salience: Math.max(0, Math.min(1, e.score ?? 0.5)), tags: e.tags ?? [] };
      });
  }
  const supersededDays = useMemo(() => new Set(mimir?.superseded_dates ?? []), [mimir]);

  function openEvent(ev: CalendarEvent) {
    const s = localDate(ev.start);
    const e = ev.end ? localDate(ev.end) : null;
    const valid = Number.isFinite(s.getTime());
    const when = !valid
      ? ev.start
      : ev.allDay
        ? `${fmtDay(s)} · all-day`
        : `${fmtDay(s)} · ${fmtTime(s)}${e && Number.isFinite(e.getTime()) ? ` – ${fmtTime(e)}` : ''}`;
    const link = valid
      ? `https://calendar.google.com/calendar/r/day/${s.getFullYear()}/${s.getMonth() + 1}/${s.getDate()}`
      : 'https://calendar.google.com/calendar/r';
    const lines = [
      `**When** · ${when}`,
      ev.attendees !== undefined ? `**Attendees** · ${ev.attendees}` : null,
      `**Source** · \`${ev.calendarId}\` · \`${ev.id}\``,
      ev.cancelled ? '**Cancelled**' : null,
      `[Open in Google Calendar](${link})`,
    ].filter(Boolean);
    openModal({
      variant: 'info',
      tone: ev.cancelled ? 'danger' : 'info',
      glyph: 'ᛅ',
      title: ev.title,
      body: 'read-only — this reckoning has no edit',
      content: lines.join('\n\n'),
      format: 'markdown',
    });
  }

  const totalPhases = Object.values(details).reduce((n, d) => n + (d.phases?.length ?? 0), 0);
  const owners = Array.from(new Set(Object.values(details).flatMap((d) => (d.phases ?? []).map((p: SmidjaPhase) => p.owner ?? 'smith'))));
  const supersededCount = supersededDays.size;

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Mánagandr · Calendar</h1>
          <p className="stage-deck">
            The month-reckoner · one read reckoning, four lanes · hour gutter in {MACHINE_ZONE}
          </p>
        </div>
        <div className="row">
          <StateChip tone={stateTone} glyph="ᛅ">{stateWord}</StateChip>
        </div>
      </div>

      <div className="metric-grid" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <MetricTile
          label="The reckoning"
          value={stateWord}
          tone={!calendar ? 'var(--ymir-info)' : state === 'ok' ? 'var(--ymir-ok)' : state === 'unknown' ? 'var(--ymir-warn)' : 'var(--ymir-info)'}
          delta={calendar?.as_of ? `as of ${new Date(calendar.as_of).toLocaleString(undefined, { hour12: false })}` : !calendar ? 'reading…' : state === 'absent' ? 'no cache · Phase 0' : 'freshness unprovable'}
        />
        <MetricTile label="Events in window" value={events.length} delta={state === 'ok' ? 'from the reader’s cache' : 'unconfirmed'} />
        <MetricTile
          label="Nornir"
          value={cron?.running ? 'RUNNING' : 'STOPPED'}
          tone={cron?.running ? 'var(--ymir-ok)' : 'var(--ymir-danger)'}
          delta={`${applyingJobs.length}/${jobs.length} jobs · ${seats.filter((s) => s.reachable).length}/${seats.length} seats`}
        />
        <MetricTile
          label="Smíðja"
          value={`${sessions.length} run${sessions.length === 1 ? '' : 's'}`}
          delta={totalPhases === 0 ? 'no forge yet · 0 phases' : `${totalPhases} phases · ${owners.length} owners`}
        />
        <MetricTile
          label="Well"
          value={mimir?.episodes ?? recall.length}
          delta={mimir ? `${supersededCount} superseded day${supersededCount === 1 ? '' : 's'}` : 'bridge down'}
        />
      </div>

      <div className="mg-toolbar">
        <div className="mg-nav">
          <button type="button" className="mg-btn" onClick={() => move(-1)} aria-label="Previous month">‹</button>
          <span className="mg-month">{monthLabel}</span>
          <button type="button" className="mg-btn" onClick={() => move(1)} aria-label="Next month">›</button>
          <button type="button" className="mg-today" onClick={goToday}>⟨ Today ⟩</button>
        </div>
        <div className="mg-lanes" role="group" aria-label="Lanes">
          {LANES.map((l) => (
            <button
              key={l.id}
              type="button"
              className={`mg-lane ${lanes.has(l.id) ? 'on' : ''}`}
              aria-pressed={lanes.has(l.id)}
              onClick={() => toggle(l.id)}
            >
              <span aria-hidden="true">{l.glyph}</span> {l.label}
            </button>
          ))}
        </div>
      </div>

      {reckoningNote ? (
        <div className={`mg-note ${!calendar ? 'muted' : state === 'absent' ? 'info' : state === 'unknown' ? 'warn' : 'muted'}`}>{reckoningNote}</div>
      ) : null}

      <div className="mg-scroll">
        <div className="mg-grid">
          {weeks.map((week, wi) => (
            <div className="mg-week" key={`${monthKey}-${wi}`}>
              <div className="mg-week-head">
                <div className="mg-gutter-spacer" />
                {week.map((d) => {
                  const inMonth = d.getMonth() === cursor.m;
                  const today = sameDay(d, now);
                  const monday = ((d.getDay() + 6) % 7) === 0;
                  return (
                    <div key={dayKey(d)} className={`mg-day-head ${inMonth ? '' : 'out'} ${today ? 'today' : ''} ${monday ? 'wk-start' : ''}`}>
                      <span className="mg-wd">{WEEKDAYS[(d.getDay() + 6) % 7]}</span>
                      <span className="mg-dom">{d.getDate()}</span>
                    </div>
                  );
                })}
              </div>

              <div className="mg-week-allday">
                <div className="mg-gutter-label">all-day</div>
                {week.map((d) => (
                  <div key={`ad-${dayKey(d)}`} className={`mg-allday-cell ${d.getMonth() === cursor.m ? '' : 'out'}`}>
                    {allDayForDay(d, events).map((ev) => (
                      <button
                        key={`${ev.id}-${dayKey(d)}`}
                        type="button"
                        className={`mg-allday-chip ${calClass(ev.calendarId)} ${ev.cancelled ? 'mg-cancelled' : ''}`}
                        onClick={() => openEvent(ev)}
                        title={`${ev.allDay ? 'all-day' : `starts ${fmtTime(localDate(ev.start))}`} · ${ev.title}`}
                      >
                        {ev.title}
                      </button>
                    ))}
                  </div>
                ))}
              </div>

              <div className="mg-week-body">
                <div className="mg-gutter">
                  {HOURS.map((h) => (
                    <div className="mg-hour" key={h} style={{ height: HOUR_H }}>
                      <span>{String(h).padStart(2, '0')}:00</span>
                    </div>
                  ))}
                </div>
                {week.map((d) => {
                  const sm = phasesForDay(d);
                  return (
                    <DayColumn
                      key={`c-${dayKey(d)}`}
                      day={d}
                      events={events}
                      hairlines={hairlinesForDay(d)}
                      phases={sm.phases}
                      sessionRails={sm.rails}
                      episodes={episodesForDay(d)}
                      superseded={supersededDays.has(dayKey(d))}
                      isToday={sameDay(d, now) && d.getMonth() === cursor.m}
                      nowMin={minutesOf(now)}
                      lanes={lanes}
                      onSelect={openEvent}
                    />
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="mg-legend">
        <span className="mg-key"><i className="mg-swatch hollow" /> planned</span>
        <span className="mg-key"><i className="mg-swatch filled" /> ran</span>
        <span className="mg-key"><i className="mg-swatch blood" /> missed / deferred</span>
        <span className="mg-key"><i className="mg-swatch event" /> event</span>
        <span className="mg-key"><i className="mg-swatch phase" /> phase</span>
        <span className="mg-key"><i className="mg-swatch tick" /> well tick</span>
        <span className="mg-key"><i className="mg-swatch rule" /> superseded fact</span>
      </div>

      <div className="gate-grid" style={{ gridTemplateColumns: 'minmax(0, 1fr) minmax(0, 1fr)' }}>
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title"><span className="glyph" aria-hidden="true">ᛃ</span> Nornir · the seats</div>
          </div>
          <div className="panel-body flush">
            <table className="data-table">
              <thead>
                <tr><th>Seat</th><th>Reachable</th><th>Runs</th></tr>
              </thead>
              <tbody>
                <tr>
                  <td className="mono">this seat</td>
                  <td><StatusChip status={cron?.running ? 'nominal' : 'down'} /></td>
                  <td className="mono num">{`${applyingJobs.length}/${jobs.length}`}</td>
                </tr>
                {seats.map((s) => (
                  <tr key={s.seat}>
                    <td className="mono">{s.seat}</td>
                    <td><StatusChip status={s.reachable ? 'nominal' : 'down'} /></td>
                    <td className="mono num">{s.reachable ? `${s.applies}/${s.jobs}` : s.error ?? 'unreachable'}</td>
                  </tr>
                ))}
                {seats.length === 0 ? (
                  <tr><td colSpan={3} className="muted" style={{ padding: 12 }}>No server seats read — /api/cron/seats answers over the ssh ring.</td></tr>
                ) : null}
              </tbody>
            </table>
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title"><span className="glyph" aria-hidden="true">ᛋ</span> Smíðja · the forge lanes</div>
          </div>
          <div className="panel-body flush">
            {smidjaDb !== 'present' && sessions.length === 0 ? (
              <div className="muted" style={{ padding: 12, fontSize: 12 }}>
                No forge yet — the smithy’s store holds no runs (db: {smidjaDb}).
              </div>
            ) : (
              <table className="data-table">
                <thead>
                  <tr><th>Owner</th><th>Run</th><th>Spend</th></tr>
                </thead>
                <tbody>
                  {sessions.length === 0 ? (
                    <tr><td colSpan={3} className="muted" style={{ padding: 12 }}>No forge yet.</td></tr>
                  ) : (
                    sessions.map((s) => (
                      <tr key={s.smidja_id}>
                        <td className="mono">{s.engineer ?? 'smith'}</td>
                        <td className="mono">{s.status ?? 'run'}</td>
                        <td className="mono num">{`${(s.total_tokens ?? 0).toLocaleString()} tk · $${(s.total_cost ?? 0).toFixed(2)}`}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            )}
            {sessions.length > 0 && totalPhases === 0 ? (
              <div className="muted" style={{ padding: '6px 12px', fontSize: 11 }}>No phases recorded yet — the run is a rail, not blocks.</div>
            ) : null}
          </div>
        </section>
      </div>
    </>
  );
}
