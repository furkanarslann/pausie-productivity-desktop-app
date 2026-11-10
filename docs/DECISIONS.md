# Decision log

Every intentional difference from the *Pausie MVP Spec*, the *MVP Implementation Guide* and the Figma
file, with when it was decided, who asked for it, why, and the commit that made it. The current behavior
as a whole is in [FLOW.md](FLOW.md).

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
