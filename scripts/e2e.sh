# End-to-end checks for LifeOS. Sourced by scripts/smoke.sh after the tab tour, with the app
# open on Home. Uses the helpers defined there (tap_text, type_text, expect, shot, ...).

# Scroll the current screen up by about half its height (works at any emulator resolution).
swipe_up() {
  local size w h
  size=$(adb shell wm size | tr -d '\r' | awk '{print $NF}' | tail -1)
  w=${size%x*}; h=${size#*x}
  adb shell input swipe $((w / 2)) $((h * 3 / 4)) $((w / 2)) $((h / 4)) 400; sleep 1
}

# --- Tasks: create, complete, then find it with search ---------------------------------------
tap_text "Tasks"; sleep 2
tap_text "New task"; sleep 2
tap_class EditText 0; type_text "Buy oat milk"; hide_keyboard
shot e2e-task-editor
tap_text "Save"; sleep 2
expect "Buy oat milk" 10 "task is created and listed"
tap_text "Complete Buy oat milk"; sleep 2
expect_not "Complete Buy oat milk" 2 "completed task leaves the open list"
tap_text "Done"; sleep 2
expect "Reopen Buy oat milk" 10 "completed task shows under Done"
tap_text "Search"; sleep 2
type_text "oat milk"; hide_keyboard
expect "Buy oat milk" 10 "search finds the completed task"
shot e2e-search
back

# --- Reminder: a task due next week with a reminder registers a system alarm -----------------
tap_text "Open"; sleep 1
tap_text "New task"; sleep 2
tap_class EditText 0; type_text "Renew passport"; hide_keyboard
tap_text "Next week"; sleep 1
has_text "1 day before" || swipe_up
tap_text "1 day before"; sleep 1
tap_text "Save"; sleep 3
expect "Renew passport" 10 "task with a reminder is saved"
expect "Reminder" 5 "task row shows its reminder"
if adb shell dumpsys alarm | grep -q "dev.basalt.lifeos"; then pass "reminder alarm is scheduled with the system"; else fail "no alarm scheduled for the reminder"; fi

# --- Notes: create one and find it with search -----------------------------------------------
tap_text "Notes"; sleep 2
tap_text "New note"; sleep 2
type_text "Packing list"
tap_class EditText 1; type_text "passport and charger"; hide_keyboard
shot e2e-note-editor
tap_text "Done"; sleep 2
expect "Packing list" 10 "note is saved"
tap_class EditText 0; type_text "charger"; hide_keyboard
expect "Packing list" 10 "notes search finds the note"
expect_not "No matching notes" 1 "notes search has a result"
shot e2e-notes

# --- Habits: add one and check it off for today ----------------------------------------------
tap_text "More"; sleep 2
shot e2e-more
tap_text "Habits"; sleep 2
tap_text "New habit"; sleep 2
type_text "Drink water"; hide_keyboard
tap_text "Save"; sleep 2
expect "Drink water" 10 "habit is created"
tap_text "Check off Drink water"; sleep 2
expect "Undo Drink water today" 10 "habit is checked off today"
expect "1-day streak" 5 "streak starts at one day"
shot e2e-habits
back

# --- Expenses: add one and see the monthly total ---------------------------------------------
tap_text "Expenses"; sleep 2
tap_text "Add expense"; sleep 2
tap_class EditText 0; type_text "12.50"
tap_class EditText 1; type_text "Lunch"; hide_keyboard
tap_text "Save"; sleep 2
expect "12.50" 10 "monthly total shows the expense"
expect "Lunch" 5 "expense is listed"
shot e2e-expenses
back

# --- Assistant: answers come from the data above ---------------------------------------------
tap_text "Assistant"; sleep 2
tap_text "Plan my day"; sleep 2
expect "Next up: Renew passport" 5 "assistant plans the day from real data"
tap_text "What's overdue?"; sleep 2
expect "Nothing is overdue" 5 "assistant answers the overdue question"
shot e2e-assistant
back

# --- Settings renders --------------------------------------------------------------------------
tap_text "Home"; sleep 2
tap_text "Settings"; sleep 2
shot e2e-settings
swipe_up; swipe_up
expect "Export backup" 5 "settings show backup options"
shot e2e-settings-data
back

# --- Calendar: add an event for today ----------------------------------------------------------
tap_text "Calendar"; sleep 2
tap_text "New event"; sleep 2
type_text "Team lunch"; hide_keyboard
tap_text "Save"; sleep 2
expect "Team lunch" 10 "event shows on the selected day"
shot e2e-calendar

# --- Relaunch: everything is still there -------------------------------------------------------
adb shell am force-stop "$PKG"; sleep 2
launch
expect "Today" 20 "app reopens on Home"
expect "Drink water" 10 "habit persisted"
expect "Team lunch" 5 "event persisted"
shot e2e-home-after-relaunch
tap_text "Tasks"; sleep 2
expect "Renew passport" 10 "open task persisted"
tap_text "Done"; sleep 2
expect "Reopen Buy oat milk" 10 "completed task persisted"
tap_text "Notes"; sleep 2
expect "Packing list" 10 "note persisted"
tap_text "More"; sleep 2
tap_text "Expenses"; sleep 2
expect "12.50" 10 "expense persisted"
back
alive || fail "app is not running at the end of the end-to-end checks"
