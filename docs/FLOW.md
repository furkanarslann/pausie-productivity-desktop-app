# Pausie: flow and logic (as built)

This is the behavior the app implements today. It started from the *Pausie MVP Spec* and the
*MVP Implementation Guide*; every place where it intentionally differs from them is recorded, with
the date and reason, in [DECISIONS.md](DECISIONS.md). When behavior changes, update this file and add
a decision entry in the same commit.

Source of truth in code:

| What | Where | Tested in |
| --- | --- | --- |
| States, events, transitions | `Pausie/Core/SessionMachine.swift` (pure reducer) | `SessionMachineTests` (one test per row) |
| Timers, reminders, sleep/lock, saving | `Pausie/Core/SessionController.swift` | `SessionControllerTests` |
| Fixed durations | `SessionRules` in `Pausie/Core/SessionState.swift` | |
| Menu bar title, menu header and rows | `Pausie/UI/StatusItem/MenuPresentation.swift` | `MenuPresentationTests` |
| Break-over sounds, settings decoding | `Pausie/Data/BreakSound.swift`, `Pausie/System/ChimePlayer.swift` | `SoundTests` |
| Todo editor rules | `Pausie/UI/NoteWindow/TodoEditorModel.swift`, `TodoTextField.swift` | `TodoEditorModelTests`, `WindowTests` |

## Core loop

**Work → note window 5 min before the break → "Save" (keep working), "Ask me later" or "Skip note for
this session" → break starts on time → "Let's go!" → see and copy the note → new cycle.**

## States

| State | When | On screen |
| --- | --- | --- |
| `idle` | App open, no timer | Menu bar icon only |
| `working` | A cycle is running, more than 5 min left | Countdown in the menu bar; the resume panel if you just came back |
| `preBreakPending` | 5 min left (or a reminder fired), no note saved | Note window, centered, editor focused |
| `preBreakSnoozed` | "Ask me later" was pressed, or the note card was snoozed (T22) | Countdown only; after "Ask me later" the note window comes back at 3 and 1 min left |
| `preBreakNoted` | The note was saved; work goes on | Countdown; menu offers "Take a break now" and "Edit note" |
| `preBreakSkipped` | "Skip note for this session" was pressed; work goes on | Countdown; menu offers "Take a break now" and "Write note now" |
| `breakNoteRequired` | Work time ended with nothing written | Dimmed screen + note card; the break timer has not started |
| `onBreak` | Break timer running | Dimmed screen + break card with the timer ring; "Let's go!" disabled |
| `breakOver` | Break time is up | "Break's over" card, the break sound for at most 1 min, "Let's go!" enabled |

**Paused** is not a state: "Pause" in the menu freezes the work timer in any work state (`working` and
the four `preBreak*` states) and the state stays as it is until "Resume" (T16, T17).

## Transitions

Numbers follow the spec. T4 ("Save & take a break") was removed; T14 to T22 are new.

| # | From | Event (trigger) | To | Effects |
| --- | --- | --- | --- | --- |
| T1 | idle | start ("Start focus session", ⌘S) | working | new cycle: settings snapshot, empty draft, work deadline |
| T2 | working | 5 min left | preBreakPending | close resume panel, open note window (pending) |
| T3 | preBreakPending | "Save" | preBreakNoted | save note, close window; work goes on |
| T5 | preBreakPending, preBreakSnoozed | work time up, draft has text | onBreak | save the draft, show break card, start break timer |
| T5 | preBreakPending, preBreakSnoozed | work time up, nothing written | breakNoteRequired | close window, show note card; break timer waits |
| T6 | preBreakNoted | work time up | onBreak | save the draft (only if edits changed it), show break card, start break timer |
| T7 | preBreakNoted | "Take a break now" (menu) | onBreak | same as T6 |
| T8 | preBreakNoted | "Edit note" (menu), then "Save" | preBreakNoted | open window (edit) with the saved note; save updates the same record |
| T9 | breakNoteRequired | "Save note & start break" | onBreak | save note, start break timer |
| T10 | onBreak | break time up | breakOver | break-over card, chime |
| T11 | breakOver | "Let's go!" | working | stop chime, hide break layer, show resume panel, new cycle |
| T12 | onBreak | "Skip break…" (menu) → confirm "Skip break" | working | hide break layer, show resume panel, new cycle |
| T13 | working, preBreakPending, preBreakSnoozed, preBreakNoted, preBreakSkipped | "Stop session" (menu) | idle | stop timers (a pause ends too), close note window |
| T14 | preBreakPending | "Ask me later" (Esc) | preBreakSnoozed | close window, schedule the next reminder |
| T15 | preBreakSnoozed | reminder at 3 / 1 min left, or "Write note now" (menu) | preBreakPending | open note window (pending) |
| T16 | any work state | "Pause" (menu) | same state | freeze the work timer |
| T17 | any work state, paused | "Resume" (menu) | same state | new work end time from the time left |
| T18 | preBreakPending | "Skip note for this session" | preBreakSkipped | close window; nothing is saved |
| T19 | preBreakSkipped | work time up, or "Take a break now" (menu) | onBreak | show break card, start break timer; nothing is saved |
| T20 | preBreakSkipped | "Write note now" (menu) | preBreakPending | open note window (pending) with anything typed before |
| T21 | breakNoteRequired | "Skip note & start break" | onBreak | start break timer; nothing is saved |
| T22 | breakNoteRequired | "Snooze for 5 min" (once per cycle) | preBreakSnoozed | hide break layer; 5 min of work with no reminders, then time up asks again (T5) |
| T22 | onBreak | "Snooze for 5 min" (once per cycle) | preBreakNoted, or preBreakSkipped if the note was skipped | hide break layer, drop the break timer; 5 min of work, then the break starts from the beginning (T6, T19) |

Any other (state, event) pair is ignored and logged.

## Rules

1. **The break timer starts only after the note is saved or skipped.** Time spent writing never comes
   out of the break.
2. **"Let's go!" is disabled until the break ends.** The only early exit from a running break is
   "Skip break…" in the menu, which asks for confirmation ("Keep resting" is the default).
3. **The break-over sound** is the one picked in Settings (default: the macOS "Glass" chime). A chime
   repeats every 10 s; a music clip (55 s) plays once. Both stop after 60 s, or when "Let's go!" is
   pressed. The break-over screen stays until the user comes back.
4. **Every path into a break saves a note**, unless the note was skipped for this cycle (T19, T21). An
   empty note is a valid save.
5. **Notes are never lost.** At time up, notes typed so far are saved and the break starts (T5).
   Edits in an open "Edit note" window are saved at time up or "Take a break now" (T6, T7). Saving
   identical text changes nothing (the note keeps its save time). Skipping is the exception: text typed
   before "Skip" stays in the draft until the cycle ends ("Write note now" brings it back) but is not
   saved when the break starts.
6. **No early break from the note window.** It offers "Skip note for this session", "Ask me later" and
   "Save". After saving or skipping, an early break is possible from the menu ("Take a break now").
7. **"Ask me later" reminders** come at 3 min and 1 min left; a reminder less than 10 s away when the
   button is pressed is skipped. After the last one, the next prompt is at time up. The draft is kept.
8. **Sleep and screen lock** pause the work timer (all `preBreak*` states included); the break timer keeps
   running, and if it ended while away, "Break's over" opens on wake.
9. **Settings:** durations apply from the next cycle; the break sound and appearance (System / Light /
   Dark) apply at once.
   Work is 6–180 min (5 min steps, must be longer than the 5 min note lead), break 1–60 min (1 min steps).
10. **The break layer** dims every display below the menu bar (the menu bar stays usable); the card shows
    on the main display.
11. **Pausie lives only in the menu bar** (no Dock icon). After quitting, it starts in `idle`; notes are kept.
12. **Pause** (menu) is offered only in work states. It freezes the work timer, the note reminders and
    time up until "Resume"; sleep and lock don't end it, and the timer runs again only when nothing
    else (sleep, lock) holds it. A pause ends with its work block: taking a break or "Stop session"
    clears it, so the next cycle starts running. A running break can't be paused.
13. **"Snooze for 5 min"** on the break cards (note card and running break) works once per cycle: the
    break layer goes away and work goes on for 5 min, then the break starts again from the beginning
    with its full length. A saved or skipped note stays as it is; with no note yet, nothing reminds
    in between and the note card comes back at time up. The button is gone after it is used, and
    comes back with the next cycle.

## Notes

- **Draft:** one per cycle, shared by the note window and the break note card. It survives "Ask me
  later" and is reset when a new cycle starts. After a save it equals the saved text.
- **Saving:** empty todo lines are dropped wherever they are; a note with no text is saved as empty.
  Saving again in the same cycle updates the same record.
- **Skipping:** a skipped cycle saves nothing, so Recent notes is unchanged and no "Welcome back!"
  panel opens after its break.
- **History:** the last 5 notes, newest first, in `~/Library/Application Support/Pausie/notes.json`.
  The sixth removes the oldest. "Recent notes" in the menu lists them with their save time.

## Screens

### Menu bar

| State | Title next to the icon |
| --- | --- |
| idle | none (icon only) |
| working, preBreakPending, preBreakSnoozed, preBreakNoted, preBreakSkipped | work time left, `mm:ss`; paused: a pause sign before it |
| breakNoteRequired | "Break" |
| onBreak | break time left, `mm:ss` |
| breakOver | `00:00` |

SF Pro Text Regular 12, monospaced digits; changed digits slide in at their exact size.

### Menu

The header shows a pose, a title and a subtitle; work states also show a progress bar. Every row has
an SF Symbol icon (`Icon.Menu` in `Metrics.swift`). In work states the first row is **Pause** (⌘P), or
**Resume** while paused, in the place where idle shows "Start focus session".

| State | Header | Rows (between separators) |
| --- | --- | --- |
| idle | Sleepy · "Pausie is resting" | Start focus session · Recent notes, Settings… · Quit Pausie |
| working, preBreakPending | Focused · "Focus session", "mm:ss left · break at HH:mm" | Pause · Recent notes, Settings… · Stop session · Quit Pausie |
| preBreakSnoozed | same as working | Pause, Write note now · Recent notes, Settings… · Stop session · Quit Pausie |
| preBreakNoted | Taking notes · "Note saved", "Break in mm:ss" | Pause, Take a break now, Edit note · Recent notes, Settings… · Stop session · Quit Pausie |
| preBreakSkipped | Focused · "No note this time", "Break in mm:ss" | Pause, Take a break now, Write note now · Recent notes, Settings… · Stop session · Quit Pausie |
| any work state, paused | Sleepy · "Paused", "mm:ss left · resume when ready" | same rows with **Resume** instead of Pause |
| breakNoteRequired | Taking notes · "Time for a break" | Recent notes, Settings… · Quit Pausie |
| onBreak | Break time · "On a break", "mm:ss left · ends at HH:mm" | Skip break… · Recent notes, Settings… · Quit Pausie |
| breakOver | Back to work · "Break's over" | Recent notes, Settings… · Quit Pausie |

### Note window

Centered on the main display, 600 pt wide; it takes the keyboard when it opens. It can be minimized
but not closed.

| Mode | Opened by | Buttons |
| --- | --- | --- |
| pending | T2, T15, T20 | **Skip note for this session** (left) · **Ask me later** (Esc) · **Save** (⌘Return) |
| edit | T8 "Edit note" | **Save** (⌘Return) |

Todo editor: each todo is a row; long todos wrap and the row grows. Return adds a todo below (not from
an empty one); Backspace in an empty todo removes it; ↑/↓ move through a todo's wrapped lines, then to
the todo above (caret at its end) or below (caret at its start). Pasted markdown is split into rows.
Clicking the empty part of the editor continues the last todo.

### Break layer

| State | Card |
| --- | --- |
| breakNoteRequired | Note card: editor + "Save note & start break" (⌘Return) + "Skip note & start break" + "Snooze for 5 min" |
| onBreak | Relaxed pose in a ring showing the time left, a speech bubble, timer, "Break ends at HH:mm", disabled "Let's go!", "Snooze for 5 min" |
| onBreak + "Skip break…" | Confirmation on top: "Skip break" / "Keep resting" (default) |
| breakOver | "Break's over!", sound chip, "Let's go!" (default), "Starts your next N min session" |

The sound chip reads "{sound} · stops after 1 min" and opens Settings (above the break layer) to change
the sound. After a skipped note the bubble says "Nothing to remember this time" and the break-over text
"Ready for a fresh start?" instead of mentioning the note.

### Note panel ("Welcome back!" / "Recent note")

Opens after T11 / T12 with the cycle's note (not after a skipped note), or when a note is picked from
Recent notes. The header depends on where it was opened:

| Opened by | Pose | Title | Subtitle |
| --- | --- | --- | --- |
| "Let's go!" or "Skip break" (T11, T12) | Happy | "Welcome back!" | "Here is where you left off." |
| A note in Recent notes | Thinking | "Recent note" | "Picked from your last 5 notes." |

 Read-only
todos; Copy puts the raw markdown on the pasteboard and shows "Copied!" for 1.5 s. It closes itself
after 15 s (paused while the pointer is over it), on "Close", or at the next 5-min warning.

### Settings

Work and break steppers (apply on Save, from the next cycle); break sound; appearance picker (applies
at once).

**Break sound** is a menu with two sections: *Music* (Morning Marimba, Ukulele Bounce, Rise & Shine,
Happy Groove: upbeat tracks written for Pausie and bundled in the app, see [SOUNDS.md](SOUNDS.md)) and *macOS sounds*
(Glass, Hero, Ping, Purr, Submarine, Tink, Bottle, Blow). Picking one saves it at once and plays a
preview (music: at most 15 s, then a 1 s fade). The ▶ / ■ button next to it plays or stops the
preview. A preview stops the break-over sound if it is playing, and stops when Settings closes.
