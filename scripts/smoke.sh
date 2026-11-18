#!/bin/bash
# Emulator smoke test for Basalt apps (Flutter and native Compose).
# Install, launch, get past the introduction, visit every tab, relaunch, then run scripts/e2e.sh.
# Usage: TABS="Tab2 Tab3" smoke.sh <apk> <package> <text that must be on screen after the introduction>
# Matching looks at both `text` and `content-desc`, because Flutter exposes most text through
# accessibility labels (one node can hold several lines, separated by newlines).
set -u
APK="$1"; PKG="$2"; EXPECT="$3"; OUT=smoke
mkdir -p "$OUT"
adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb install -r -g "$APK" || { echo "INSTALL FAILED"; exit 1; }
adb logcat -c

dump() { adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 && adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1; }
shot() { adb exec-out screencap -p > "$OUT/$1.png"; dump && cp /tmp/ui.xml "$OUT/$1.xml"; }

# Print "x y" of a node. Mode: exact (whole text/desc or one whole line of it) | contains | res | class.
_find() {
  python3 - "$1" "$2" "${3:-0.5}" "${4:-0.5}" "${5:-last}" <<'PY'
import re, sys, html
mode, want, fx, fy, pick = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
try:
    xml = open('/tmp/ui.xml', encoding='utf-8', errors='ignore').read()
except Exception:
    sys.exit(0)
hits = []
for m in re.finditer(r'<node [^>]*>', xml):
    n = m.group(0)
    vals = [html.unescape(v) for v in re.findall(r' (?:text|content-desc)="([^"]*)"', n)]
    ok = False
    if mode == 'exact':
        ok = any(v == want or want in v.split('\n') for v in vals)
    elif mode == 'contains':
        ok = any(want in v for v in vals)
    elif mode == 'res':
        r = re.search(r'resource-id="([^"]*)"', n); ok = bool(r and r.group(1).endswith(want))
    elif mode == 'class':
        c = re.search(r' class="([^"]*)"', n); ok = bool(c and c.group(1).endswith(want))
    if ok:
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if b:
            x1, y1, x2, y2 = map(int, b.groups())
            if x2 > x1 and y2 > y1:
                hits.append((int(x1 + (x2 - x1) * fx), int(y1 + (y2 - y1) * fy)))
if hits:
    if pick == 'last': h = hits[-1]
    elif pick == 'first': h = hits[0]
    else: h = hits[min(int(pick), len(hits) - 1)]
    print(*h)
PY
}
_tap() { local xy; dump; xy=$(_find "$@"); [ -n "$xy" ] && adb shell input tap $xy && echo "tapped [$1] '$2' at $xy"; }
# Tap a node whose text/label is exactly this (or has it as one whole line). Last match wins
# (the tab bar is drawn last, on top of anything with the same name).
tap_text() { _tap exact "$1"; }
tap_first() { _tap exact "$1" 0.5 0.5 first; }
tap_contains() { _tap contains "$1"; }
# Tap the Nth (0-based) node of a class, e.g. tap_class EditText 0 for the first text field.
tap_class() { _tap class "$1" 0.5 0.5 "${2:-0}"; }
tap_res() { _tap res "$1" "${2:-0.5}" "${3:-0.5}" first; }
has_text() { dump; [ -n "$(_find contains "$1")" ]; }
wait_contains() { for i in $(seq 1 ${2:-20}); do has_text "$1" && return 0; sleep 3; done; return 1; }
wait_for() { wait_contains "$1" "${2:-30}"; }
scroll_to() {
  for i in $(seq 1 8); do has_text "$1" && return 0; adb shell input swipe 540 1500 540 700 300; sleep 1; done
  has_text "$1"
}
scroll_top() { for i in 1 2 3 4; do adb shell input swipe 540 600 540 1600 200; done; sleep 1; }
# Type into the focused field. Spaces become %s for `input text`.
type_text() { adb shell input text "$(printf '%s' "$1" | sed 's/ /%s/g; s/'"'"'/\\'"'"'/g')"; sleep 1; }
hide_keyboard() { adb shell input keyevent 111; sleep 1; }
back() { adb shell input keyevent 4; sleep 2; }

FAILED=0
fail() { echo "E2E FAIL: $*"; FAILED=1; }
pass() { echo "E2E PASS: $*"; }
expect() { if wait_contains "$1" "${2:-10}" || scroll_to "$1"; then pass "$3"; else fail "$3 (did not see '$1')"; shot "fail-$(echo "$3" | tr -c 'a-zA-Z0-9' '-' | cut -c1-40)"; fi; }
expect_not() { sleep "${2:-3}"; if has_text "$1"; then fail "$3 (still saw '$1')"; else pass "$3"; fi; }
alive() { [ -n "$(adb shell pidof "$PKG" | tr -d '\r')" ]; }

launch() { adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1; }

launch
wait_for "Skip" 20 || echo "introduction never appeared"
shot 1-launch
tap_text "Skip" || echo "no Skip found"
sleep 2
# Some apps show one setup screen after the introduction (scripts/after-intro.sh handles it).
[ -f scripts/after-intro.sh ] && source scripts/after-intro.sh
wait_for "$EXPECT" 20 || echo "EXPECTED TEXT NOT FOUND AFTER INTRO: $EXPECT"
sleep 3
shot 2-after-intro
for label in ${TABS:-}; do
  label="${label//_/ }"
  tap_text "$label" && sleep 4 && shot "tab-${label// /-}"
  alive || fail "app died after opening the $label tab"
done
adb shell am force-stop "$PKG"; sleep 2
launch
wait_for "$EXPECT" 20 || echo "EXPECTED TEXT NOT FOUND AFTER RELAUNCH: $EXPECT"
shot 3-relaunch
adb logcat -d -v time > "$OUT/logcat.txt"
grep -E "flutter|AndroidRuntime|FATAL|Exception" "$OUT/logcat.txt" | tail -200 > "$OUT/errors.txt" || true
echo "---- labels on screen after intro ----"
python3 - "$OUT/2-after-intro.xml" <<'PY' || true
import re, sys, html
try:
    xml = open(sys.argv[1], encoding='utf-8', errors='ignore').read()
    print([html.unescape(t) for t in re.findall(r' (?:text|content-desc)="([^"]+)"', xml)][:60])
except Exception as e:
    print("no dump", e)
PY
echo "---- errors ----"
head -80 "$OUT/errors.txt"

if [ -f scripts/e2e.sh ]; then
  echo "---- end-to-end ----"
  adb logcat -c
  source scripts/e2e.sh
  adb logcat -d -v time > "$OUT/logcat-e2e.txt"
  grep -E "AndroidRuntime|FATAL|E/flutter" "$OUT/logcat-e2e.txt" | head -60
  grep -q "FATAL EXCEPTION" "$OUT/logcat-e2e.txt" && fail "the app crashed during end-to-end tests"
  grep -q "E/flutter" "$OUT/logcat-e2e.txt" && fail "uncaught Flutter error during end-to-end tests (see logcat-e2e.txt)"
fi

has_in() { python3 -c "import re,sys,html;x=open(sys.argv[1],errors='ignore').read();sys.exit(0 if any(sys.argv[2] in html.unescape(v) for v in re.findall(r' (?:text|content-desc)=\"([^\"]*)\"',x)) else 1)" "$1" "$2"; }
has_in "$OUT/2-after-intro.xml" "$EXPECT" && has_in "$OUT/3-relaunch.xml" "$EXPECT" || { echo "SMOKE TEST FAILED: '$EXPECT' not on screen"; exit 1; }
[ "$FAILED" = 0 ] || { echo "END-TO-END TESTS FAILED"; exit 1; }
echo "SMOKE TEST PASSED"
