# Decision log

Every intentional difference from the *Pausie MVP Spec*, the *MVP Implementation Guide* and the Figma
file, with when it was decided, who asked for it, why, and the commit that made it. The current behavior
as a whole is in [FLOW.md](FLOW.md).

The *Pausie MVP Spec* doc was brought in line with D1–D13 on 2026-11-10 (states, transitions T1–T15,
rules, screens, the state diagram, and a "Kararlar (4. tur, uygulama sırasında)" section); D14 was added
to that section the same day. D15–D18 went in on 2026-11-13: the `PRE_BREAK_SKIPPED` state, T16–T21,
rules, screens, a redrawn state diagram, and rows 15–18 of that section. Keep both in step: a new
decision goes here and into the spec.

Add an entry whenever behavior changes on purpose: newest at the bottom, one entry per decision, and
mark entries that a later decision replaced instead of deleting them.

**Requested by:** "Furkan" = product owner request in the working session; "Implementation" = a
technical choice made while building, within the spec's intent.

---

### D1 · Guide's open points resolved with its proposals
- **Date:** 2026-11-09 · **Requested by:** Implementation (guide's defaults) · **Commit:** `0f0e0a8`
- **Decision:** macOS 14 minimum; break-over sound = system "Glass", repeating every 10 s, stopping at
  60 s; no launch at login; after quitting, the app starts in `idle` (notes kept); Apple logo kept on
  the Focused pose; distribution only to the owner's Mac (no notarization).
- **Why:** The guide marked these as proposals to use unless answered otherwise.
- **Note:** D15 makes the break-over sound a setting; "Glass" stays the default.

### D2 · Native menu chrome
- **Date:** 2026-11-09 · **Requested by:** Implementation (per the guide) · **Commit:** `4451dbd`
- **Decision:** The status menu is an `NSMenu` with a SwiftUI header, so its background and
  highlighted row use the system look instead of the custom Figma popover.
- **Why:** The guide chose `NSMenu` to get a native "Recent notes" submenu plus a custom header.

### D3 · Smaller implementation choices
- **Date:** 2026-11-09 · **Requested by:** Implementation · **Commit:** `4451dbd`
- **Decision:**
  - Steppers move work time in 5 min steps (6–180 min) and break time in 1 min steps (1–60 min).
  - The backdrop blur under the 45% dim approximates Figma's 5 pt blur (`OpacityToken.breakBlur`).
  - The copy icon is the SF Symbol `doc.on.doc` tinted `brand/primary`.
  - Countdowns are zero-padded `mm:ss`, except the note window sentence ("Break starts in 4:52"), as in
    Figma; clock times follow the system locale.
  - Strings added beyond the guide's catalog: `menu.recentNotes.emptyNote`, `resume.emptyNote`,
    `menubar.accessibilityLabel`, and later `noteWindow.action.askLater`, `menu.item.writeNote`.
- **Why:** Not specified, or not directly possible with native controls.

### D4 · Deleting todos; empty todos are never saved
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `01b327e`
- **Decision:** Backspace in an empty todo removes the whole todo. On save, empty todo lines are dropped
  wherever they are (the guide only dropped trailing ones); older notes skip them when shown.
- **Why:** A todo the user deleted stayed behind as an empty checkbox.

### D5 · "Welcome back!" panel closes after 15 s
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `01b327e`
- **Decision:** The resume panel closes itself after 15 s; the countdown pauses while the pointer is over
  it. It still closes on "Close" and at the next 5-min warning.
- **Supersedes:** Spec rule 8 ("stays until the user closes it").
- **Why:** The note is reachable from Recent notes anyway.

### D6 · Return in an empty todo doesn't add a line
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `865393b`
- **Decision:** Return does nothing in an empty (or blank) todo.
- **Why:** Return could stack up empty todos.

### D7 · Centered note window (Figma 03b) and break timer ring (Figma 05)
- **Date:** 2026-11-10 · **Requested by:** Furkan (with updated Figma frames 27:323, 6:77, 8:61) · **Commit:** `201fe87`
- **Decision:** The pre-break note window is centered on the main display, 600 pt wide, and focuses the
  editor when it opens (it no longer waits at the top right without the keyboard). The break card shows
  the relaxed pose inside a ring whose arc is the time left.
- **Supersedes:** Figma screen 03 (top-right 460 pt window) and the guide's "top right" placement.

### D8 · Window sizing without AppKit's automatic sizing (crash fix)
- **Date:** 2026-11-10 · **Requested by:** Implementation (fix for a crash Furkan hit) · **Commit:** `18c3643`
- **Decision:** Panels are sized from their SwiftUI content once on open, then only on whole-point height
  changes on the next run loop turn (`PanelSizing.swift`), instead of `sizingOptions = .preferredContentSize`.
- **Why:** Opening a note with long wrapped lines from Recent notes on a 1x display overflowed the stack:
  AppKit kept rounding a fractional height and each resize triggered layout and another resize.

### D9 · "Ask me later" with reminders at 3 and 1 min left (T14, T15)
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `86b33c6`
- **Decision:** The note window has "Ask me later": it closes and comes back at 3 min and at 1 min left;
  after that, the break screen asks at time up. A reminder less than 10 s away is skipped. The menu
  offers "Write note now" meanwhile, and the draft is kept.
- **Why:** Lets the user postpone writing without losing the reminder.

### D10 · Notes are never lost when work time runs out
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `86b33c6` (extended in `638a9b0`)
- **Decision:** At time up, notes typed so far are saved and the break starts (T5). The note-required
  screen appears only if nothing was written. Edits in an open "Edit note" window are saved at time up or
  on "Take a break now" (T6, T7); saving identical text keeps the original save time.
- **Supersedes:** Spec T5 (always show the note-required screen at time up).

### D11 · Wrapping todos; ↑/↓ through wrapped lines
- **Date:** 2026-11-10 · **Requested by:** Furkan (bug: caret disappeared moving between todos) · **Commit:** `86b33c6`
- **Decision:** Long todos wrap and the row grows (as the Figma todo row describes). ↑/↓ move through a
  todo's lines first, then to the todo above (caret at its end) or below (caret at its start).
- **Why:** Rows were single-line fields that scrolled sideways; moving into a todo longer than the row put
  the caret out of view.

### D12 · Lighter menu bar timer; digits slide without scaling
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commits:** `86b33c6`, `75a3e3d`
- **Decision:** The countdown uses SF Pro Text Regular 12 (Figma: Semibold 13). Changed digits slide in at
  their exact size (`RollingText`).
- **Why:** The bold timer was too heavy. The first animation (`.numericText`) scaled and blurred digits,
  so they grew and shrank every second; it was replaced the same day.

### D13 · Note window: "Ask me later | Save", no early break from it
- **Date:** 2026-11-10 · **Requested by:** Furkan · **Commit:** `638a9b0`
- **Decision:** The note window offers only "Ask me later" (Esc) and "Save" (⌘Return). Save stores the note
  and work goes on until the break starts on time (T3, T6). After saving, the menu offers "Take a break
  now" (T7, kept on Furkan's confirmation) and "Edit note" (T8). "Save & take a break" (T4) is removed.
- **Supersedes:** Spec T4 and the note window's two buttons ("Save & keep working", "Save & take a break").
- **Note:** An interim version in `86b33c6` had removed "Save & keep working", the saved-note state,
  "Take a break now" and "Edit note"; this decision restored them in the form above.

### D14 · Crisp strokes on 1x displays; an edge on secondary buttons
- **Date:** 2026-11-10 · **Requested by:** Furkan (light mode on a 27" 1080p monitor) · **Commit:** the
  commit that mentions D14 (`git log --grep D14`)
- **Decision:**
  - The focused note editor border and the todo checkbox stroke (Figma: 1.5pt) are drawn in whole
    pixels: unchanged on Retina (3px), 2px and 1px on a 1x display (`StrokeWidth` in `Metrics.swift`).
  - Secondary buttons ("Ask me later", "Skip break") have a 1pt `brand/lavender` edge at 50% on every
    display, in light and dark.
- **Supersedes:** Figma's 1.5pt strokes on 1x displays, and Figma `Button / Secondary` (no edge).
- **Why:** On a 1x display a 1.5pt line falls between pixels. It blurred and came out 1px on the top
  and left but 2px on the bottom and right, which looked like a double frame next to the focus ring.
  The pale secondary fill had almost no contrast against the white window, so the button looked washed
  out. Furkan chose the edge over a darker fill from 1x mockups.

### D15 · Break-over sound: public-domain music or a macOS chime, picked in Settings
- **Superseded in part by D20:** the four classical recordings were replaced by upbeat music written for
  Pausie. The rest of this decision stands.
- **Date:** 2026-11-13 · **Requested by:** Furkan · **Commit:** the commit that mentions D15
  (`git log --grep D15`)
- **Decision:**
  - Settings has a "Break sound" menu with two sections: *Music*, four public-domain recordings bundled
    in the app (Satie, Schumann, Bach, Chopin), and *macOS sounds*, eight system chimes. "Glass" stays
    the default.
  - Music plays once (a 55 s clip with fades); a chime repeats every 10 s. Both stop after 60 s or at
    "Let's go!" (rule 3).
  - Picking a sound saves it at once and plays a preview (music: 15 s, then a fade); a ▶ / ■ button
    plays or stops it.
  - The break-over chip names the sound ("{sound} · stops after 1 min") and opens Settings.
  - *Implementation:* the picker is the native macOS pop-up menu (Figma has no sound row). Only
    recordings that are themselves public domain or CC0 are bundled; sources, licenses and the uploads
    rejected for a CC BY license are in [SOUNDS.md](SOUNDS.md). That is why Debussy's *Clair de lune*
    became Schumann's *Träumerei*. Basso, Funk, Frog, Morse, Pop and Sosumi are left out as too harsh
    for a gentle return.
- **Supersedes:** The fixed "Glass" sound (D1) and the static chime chip ("Gentle chime · stops after
  1 min") in the spec and Figma.
- **Why:** Furkan wanted alternatives to the one chime, including royalty-free music, a way to choose
  in Settings, and a shortcut to that choice from the break-over screen.

### D16 · Pause from the menu; icons on every menu row
- **Date:** 2026-11-13 · **Requested by:** Furkan · **Commit:** the commit that mentions D16
  (`git log --grep D16`)
- **Decision:**
  - In every work state the menu's first row is "Pause" (⌘P), or "Resume" while paused, where idle
    shows "Start focus session". Pause freezes the work timer, the note reminders and time up; the
    state doesn't change (T16, T17).
  - While paused the header shows the sleepy pose, "Paused" and "mm:ss left · resume when ready" (no
    break time, since it isn't known yet), and the menu bar shows a pause sign before the frozen countdown.
  - A pause ends with its work block: taking a break or "Stop session" clears it. A running break
    can't be paused: it already has "Skip break…", and a paused break would keep the screen dimmed.
  - Every menu row has an SF Symbol icon.
- **Supersedes:** The spec's screen 01 rows (no pause, no icons); before this only sleep and screen lock
  paused the work timer.
- **Why:** Furkan wanted to stop the clock for an interruption without ending the session, and icons
  make the menu quicker to scan.

### D17 · Skip the note for one cycle
- **Date:** 2026-11-13 · **Requested by:** Furkan · **Commit:** the commit that mentions D17
  (`git log --grep D17`)
- **Decision:**
  - The note window has "Skip note for this session" on the left. It closes the window and work goes
    on with no more reminders; the break starts on time and nothing is saved (T18, T19). "Take a break
    now" stays in the menu, and "Write note now" brings the window back with anything typed (T20).
  - The break note card has "Skip note & start break" under "Save note & start break" (T21).
  - A skipped cycle adds nothing to Recent notes and opens no "Welcome back!" panel; the break cards
    say "Nothing to remember this time" / "Ready for a fresh start?" instead of mentioning the note.
  - "Session" means one work block: the next cycle asks for a note again.
- **Supersedes:** Spec rules 1 and 4 ("every path into a break saves a note"; the break timer waits for a
  saved note), and the "Welcome back!" panel's fallback to the latest saved note.
- **Why:** Not every session has something worth noting. Saving empty notes instead would push real
  notes out of the last 5 in Recent notes.

### D18 · The note panel's header depends on where it was opened
- **Date:** 2026-11-13 · **Requested by:** Furkan · **Commit:** the commit that mentions D18
  (`git log --grep D18`)
- **Decision:** After "Let's go!" or a skipped break the panel keeps "Welcome back!" / "Here is where
  you left off." with the happy pose. Opened from Recent notes it shows "Recent note" / "Picked from your
  last 5 notes." with the thinking pose. The todos, copy button, footer and auto-close are the same.
- **Supersedes:** Figma screen 08's single header ("Welcome back!"), used for both until now.
- **Why:** The panel also opens from Recent notes, often mid-session, where "Welcome back!" doesn't fit.

### D19 · Snooze a break for 5 min, once per cycle
- **Date:** 2026-11-16 · **Requested by:** Furkan · **Commit:** the commit that mentions D19
  (`git log --grep D19`)
- **Decision:**
  - The break note card and the running break card have "Snooze for 5 min". It hides the break layer
    and gives 5 more minutes of work; then the break starts again from the beginning, with its full
    length (T22).
  - It works once per cycle: the button is gone after it is used and comes back with the next cycle.
    It isn't offered on the break-over card or in the menu.
  - A saved note stays saved (`preBreakNoted`) and a skipped one stays skipped (`preBreakSkipped`).
    Snoozed from the note card, the cycle goes to `preBreakSnoozed` with no "Ask me later" reminders,
    so the 5 min aren't interrupted; anything typed on the card is kept and saved at time up (T5).
- **Supersedes:** Spec rule 2 as the only way out of a running break was "Skip break…"; the spec and
  Figma had no way to postpone a break.
- **Why:** The break screen can arrive in the middle of a task; 5 minutes to finish it is better than
  skipping the break.

### D20 · Upbeat music written for Pausie instead of the classical clips
- **Date:** 2026-11-16 · **Requested by:** Furkan · **Commit:** the commit that mentions D20
  (`git log --grep D20`)
- **Decision:**
  - The *Music* section of "Break sound" has four upbeat tracks: Morning Marimba, Ukulele Bounce,
    Rise & Shine and Happy Groove. They replace the Satie, Schumann, Bach and Chopin recordings.
  - The tracks were composed for Pausie and synthesized from code (`Tools/BreakMusic`), with no
    samples or third-party recordings, so they are royalty-free by construction. Each is 55 s, starts
    on its hook like an alarm, and keeps the earlier loudness (−18 LUFS, −3 dB true peak), with little
    high-frequency energy and soft percussion so it doesn't grate.
  - A setting that still names a classical clip plays Morning Marimba, so a user who picked music keeps
    music. "Glass" stays the default.
- **Supersedes:** The music part of D15.
- **Why:** Furkan found the classical pieces too heavy for the end of a break and wanted something
  energetic and alarm-like that is still easy on the ears.
