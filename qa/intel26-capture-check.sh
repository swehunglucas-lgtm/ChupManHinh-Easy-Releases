#!/usr/bin/env bash
set -euo pipefail
ROOT="$RUNNER_TEMP/intel26-e2e"
mkdir -p "$ROOT"
REPORT="$ROOT/result.txt"
touch "$REPORT"
say(){ echo "$*" | tee -a "$REPORT"; }
say "ARCH=$(uname -m)"
say "CPU=$(sysctl -n machdep.cpu.brand_string)"
say "OS=$(sw_vers -productVersion)"
test "$(uname -m)" = "x86_64"
BASE="https://github.com/swehunglucas-lgtm/ChupManHinh-Easy-Releases/releases/download/v2.4.1-intel-rc1"
curl -fsSL --retry 3 "$BASE/ChupManHinh-Easy-v2.4.1-macOS-Universal.dmg" -o "$ROOT/app.dmg"
curl -fsSL --retry 3 "$BASE/SHA256SUMS-v2.4.1-intel-rc1.txt" -o "$ROOT/sha256.txt"
EXPECTED="$(awk '{print $1}' "$ROOT/sha256.txt")"
ACTUAL="$(shasum -a 256 "$ROOT/app.dmg" | awk '{print $1}')"
test "$EXPECTED" = "$ACTUAL"
say "RC1_SHA256=PASS"
mkdir "$ROOT/mounted"
hdiutil attach "$ROOT/app.dmg" -readonly -nobrowse -mountpoint "$ROOT/mounted" >/dev/null
APP="$HOME/Applications/Chup Man Hinh Nhanh.app"
mkdir -p "$HOME/Applications"
ditto "$ROOT/mounted/Chup Man Hinh Nhanh.app" "$APP"
hdiutil detach "$ROOT/mounted" -quiet
codesign --verify --deep --strict "$APP"
BIN="$APP/Contents/MacOS/ScreenShotQuick"
test "$(uname -m)" = "x86_64"
say "APP_INSTALL=PASS"

cat >"$ROOT/permission-probe.swift" <<'SWIFT'
import AppKit
import ApplicationServices
import CoreGraphics
print("SCREEN_PREFLIGHT_CURRENT_DIAGNOSTIC_PROCESS=\(CGPreflightScreenCaptureAccess())")
print("ACCESSIBILITY_CURRENT_DIAGNOSTIC_PROCESS=\(AXIsProcessTrusted())")
SWIFT
swiftc "$ROOT/permission-probe.swift" -o "$ROOT/permission-probe" -framework AppKit -framework ApplicationServices
"$ROOT/permission-probe" | tee "$ROOT/permissions.txt"
say "NOTE=probe permissions refer to diagnostic process, not to app bundle"

export SSQ_SESSION_ROOT="$ROOT/Sessions"
mkdir -p "$SSQ_SESSION_ROOT"
"$BIN" --glass-preview >"$ROOT/app.log" 2>&1 &
APP_PID=$!
say "APP_PID=$APP_PID"
trap 'kill -TERM "$APP_PID" 2>/dev/null || true' EXIT
sleep 5
kill -0 "$APP_PID"
say "GLASS_APP_PROCESS=PASS"
screencapture -x "$ROOT/glass-before.png" 2>"$ROOT/screencapture.log" || true
# Query actual UI accessibility tree, without changing system permission DB.
osascript <<'OSA' >"$ROOT/ax-elements.txt" 2>"$ROOT/ax-error.txt" || true
tell application "System Events"
  tell process "ScreenShotQuick"
    set windowNames to name of every window
    set buttonNames to name of every button of window 1
    return {windowNames, buttonNames}
  end tell
end tell
OSA
cat "$ROOT/ax-elements.txt"
if test -s "$ROOT/ax-error.txt"; then tail -c 700 "$ROOT/ax-error.txt"; fi

# The original app registers cmd+option+1 for "capture main screen".
# Send the real keyboard shortcut; do not simulate the app's capture logic.
osascript -e 'tell application "System Events" to key code 18 using {command down, option down}' \
  >"$ROOT/hotkey.log" 2>&1 || true
sleep 7
PHOTO_DIR="$HOME/Desktop/Ảnh chụp màn hình"
PHOTO="$(find "$PHOTO_DIR" -maxdepth 1 -name 'Anh-chup-*-man-hinh-chinh.png' -type f -print -quit 2>/dev/null || true)"
if test -n "$PHOTO" && test -s "$PHOTO"; then
  cp "$PHOTO" "$ROOT/app-main-capture.png"
  sips -g pixelWidth -g pixelHeight "$ROOT/app-main-capture.png" >"$ROOT/main-capture-dimensions.txt"
  say "APP_MAIN_SCREEN_CAPTURE=PASS"
else
  say "APP_MAIN_SCREEN_CAPTURE=NOT_VERIFIED_PERMISSION_OR_UI_AUTOMATION"
  screencapture -x "$ROOT/glass-after.png" 2>/dev/null || true
fi

# Native Accessibility capability must be established before auto scroll can run.
# Read-only window enumeration and an app UI action, no TCC database writes.
if ! grep -q 'Glass Preview' "$ROOT/ax-elements.txt" 2>/dev/null; then
  say "APP_ACCESSIBILITY_UI_TREE=NOT_VERIFIED"
else
  say "APP_ACCESSIBILITY_UI_TREE=ACCESSIBLE"
fi

# Real auto-scroll candidate: create an independent, vertically scrollable Cocoa window
# with 150 rows. It must be visible in Quartz and take real synthetic scroll events.
cat >"$ROOT/ScrollFixture.swift" <<'SWIFT'
import AppKit
@main
final class ScrollFixture:NSObject,NSApplicationDelegate {
    private var window:NSWindow!
    static let shared=ScrollFixture()
    static func main(){
        let app=NSApplication.shared
        app.delegate=shared
        app.setActivationPolicy(.regular)
        app.run()
    }
    func applicationDidFinishLaunching(_ notification:Notification){
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:610),
                        styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title="INTEL AUTOSCROLL FIXTURE"
        window.center()
        let scroll=NSScrollView(frame:NSRect(x:0,y:0,width:740,height:575))
        scroll.hasVerticalScroller=true
        scroll.hasHorizontalScroller=false
        let text=NSTextView(frame:NSRect(x:0,y:0,width:710,height:10000))
        text.isEditable=false
        text.font=NSFont.monospacedSystemFont(ofSize:16,weight:.regular)
        text.string=(0..<170).map { String(format:"INTEL FIXTURE ROW %03d — long document capture QA", $0) }.joined(separator:"\n\n")
        scroll.documentView=text
        window.contentView=scroll
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
    }
}
SWIFT
swiftc -parse-as-library "$ROOT/ScrollFixture.swift" -framework AppKit -o "$ROOT/ScrollFixture"
"$ROOT/ScrollFixture" >"$ROOT/fixture.log" 2>&1 &
FIXTURE_PID=$!
trap 'kill -TERM "$FIXTURE_PID" 2>/dev/null || true; kill -TERM "$APP_PID" 2>/dev/null || true' EXIT
sleep 4
kill -0 "$FIXTURE_PID"
say "SCROLL_TARGET_WINDOW=PROCESS_RUNNING"
# Studio may be in front after the main-screen capture; raise a fresh real
# Glass Preview window from the *existing app instance*. Never call a mock.
"$BIN" --glass-preview >"$ROOT/reshow-glass.log" 2>&1 || true
sleep 3
cat >"$ROOT/click-native-glass.swift" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation
let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],
    kCGNullWindowID) as? [[String:Any]] ?? []
guard let item=windows.first(where:{
    ($0[kCGWindowName as String] as? String ?? "").contains("Glass Preview")
}), let dictionary=item[kCGWindowBounds as String] as? [String:Any],
    let rect=CGRect(dictionaryRepresentation:dictionary as CFDictionary) else {
    fputs("GLASS_WINDOW_NOT_FOUND\n",stderr)
    exit(3)
}
// The "Tự cuộn toàn bộ trang" tile is 270pt below the real window origin.
// The click location is relative to bounds returned by Quartz, not a fixed
// screenshot coordinate; this works with moving displays/window positions.
let point=CGPoint(x:rect.midX,y:rect.minY+270)
print("GLASS_BOUNDS=\(rect)")
print("CLICK_POINT=\(point)")
for kind in [CGEventType.mouseMoved,.leftMouseDown,.leftMouseUp] {
    CGEvent(mouseEventSource:nil,mouseType:kind,mouseCursorPosition:point,
            mouseButton:.left)?.post(tap:.cghidEventTap)
    Thread.sleep(forTimeInterval:0.14)
}
SWIFT
swiftc "$ROOT/click-native-glass.swift" -framework AppKit -o "$ROOT/click-native-glass"
"$ROOT/click-native-glass" >"$ROOT/click.log" 2>&1 || true
cat "$ROOT/click.log"
sleep 2
screencapture -x "$ROOT/scroll-modal-before-start.png" 2>/dev/null || true
osascript <<'OSA' >"$ROOT/scroll-start.log" 2>&1 || true
tell application "System Events"
  tell process "ScreenShotQuick"
    set frontmost to true
    keystroke return
  end tell
end tell
OSA
# The real scroll engine may take more than ten seconds as it joins frames.
for i in $(seq 1 26); do
  if find "$PHOTO_DIR" -maxdepth 1 -name 'ChupManHinhEasy-TuCuon-*.png' -type f -print -quit 2>/dev/null | grep -q .; then
    break
  fi
  sleep 3
done
SCROLL="$(find "$PHOTO_DIR" -maxdepth 1 -name 'ChupManHinhEasy-TuCuon-*.png' -type f -print -quit 2>/dev/null || true)"
if test -n "$SCROLL" && test -s "$SCROLL"; then
  cp "$SCROLL" "$ROOT/real-auto-scroll.png"
  sips -g pixelWidth -g pixelHeight "$ROOT/real-auto-scroll.png" >"$ROOT/scroll-dimensions.txt"
  HEIGHT="$(awk '/pixelHeight:/ {print $2}' "$ROOT/scroll-dimensions.txt")"
  if [[ "$HEIGHT" =~ ^[0-9]+$ ]] && ((HEIGHT > 760)); then
    say "APP_AUTOSCROLL_OUTPUT=PASS_HEIGHT_$HEIGHT"
  else
    say "APP_AUTOSCROLL_OUTPUT=IMAGE_EXISTS_HEIGHT_NOT_CONFIRMED_$HEIGHT"
  fi
else
  say "APP_AUTOSCROLL_OUTPUT=NOT_VERIFIED_TCC_OR_AUTOMATION_OR_CAPTURE"
fi
screencapture -x "$ROOT/final-desktop.png" 2>/dev/null || true
say "NATIVE_INTEL_DIAGNOSTIC_COMPLETE"
