#!/usr/bin/env bash
set -euo pipefail
ROOT="$RUNNER_TEMP/intel26-browser-scroll"
mkdir -p "$ROOT"
REPORT="$ROOT/result.txt"
say(){ printf '%s\n' "$*" | tee -a "$REPORT"; }
say "ARCH=$(uname -m)"
say "OS=$(sw_vers -productVersion)"
say "CPU=$(sysctl -n machdep.cpu.brand_string)"
test "$(uname -m)" = "x86_64"

BASE="https://github.com/swehunglucas-lgtm/ChupManHinh-Easy-Releases/releases/download/v2.4.1-intel-rc1"
curl -fLsS --retry 3 "$BASE/ChupManHinh-Easy-v2.4.1-macOS-Universal.dmg" -o "$ROOT/app.dmg"
curl -fLsS --retry 3 "$BASE/SHA256SUMS-v2.4.1-intel-rc1.txt" -o "$ROOT/sha256.txt"
test "$(shasum -a 256 "$ROOT/app.dmg" | awk '{print $1}')" = "$(awk '{print $1}' "$ROOT/sha256.txt")"
say "PUBLISHED_RC1_HASH=PASS"
mkdir "$ROOT/dmg"
hdiutil attach "$ROOT/app.dmg" -nobrowse -readonly -mountpoint "$ROOT/dmg" >/dev/null
mkdir -p "$HOME/Applications"
APP="$HOME/Applications/Chup Man Hinh Nhanh.app"
ditto "$ROOT/dmg/Chup Man Hinh Nhanh.app" "$APP"
hdiutil detach "$ROOT/dmg" -quiet
codesign --verify --deep --strict "$APP"
BIN="$APP/Contents/MacOS/ScreenShotQuick"
export SSQ_SESSION_ROOT="$ROOT/Sessions"
mkdir -p "$SSQ_SESSION_ROOT"
say "APP_INSTALL=PASS"

python3 - "$ROOT/scroll.html" <<'PY'
import html,pathlib,sys
path=pathlib.Path(sys.argv[1])
parts=['<!doctype html><html><head><meta charset="UTF-8"><title>SSQ INTEL CHROME LONG SCROLL</title><style>',
'html{scroll-behavior:auto}body{margin:0;font:18px system-ui;background:#f0f4ff;color:#10213b}',
'header{padding:30px;background:#243e88;color:white;font-size:30px}',
'article{padding:18px 35px;min-height:100px;border-bottom:1px solid #777;background:linear-gradient(90deg,#e6f2ff,#fff)}',
'article:nth-child(even){background:linear-gradient(90deg,#fff2ed,#fff)}',
'</style></head><body><header>SSQ INTEL LONG SCROLL TEST</header>']
for i in range(120):
  parts.append(f'<article><h3>Section {i:03d}</h3><p>Unique verification row {i:03d} — This page must genuinely scroll before exporting a stitched PNG.</p></article>')
parts.append('</body></html>')
path.write_text(''.join(parts),encoding='utf-8')
PY
CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
if [ ! -x "$CHROME" ]; then say "CHROME_TARGET=UNAVAILABLE";exit 2;fi
"$CHROME" --user-data-dir="$ROOT/chrome-profile" --no-first-run --no-default-browser-check --disable-background-networking --new-window "file://$ROOT/scroll.html" >"$ROOT/chrome.log" 2>&1 &
CHROME_PID=$!
trap 'kill -TERM "$CHROME_PID" 2>/dev/null || true' EXIT
sleep 6
say "CHROME_PROCESS_STARTED=$CHROME_PID"
swift -e 'import AppKit;import CoreGraphics;let a=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? [];for e in a{let o=e[kCGWindowOwnerName as String] as? String ?? "";if o.contains("Chrome"){print("CHROME_WINDOW",e[kCGWindowNumber as String] ?? 0,e[kCGWindowName as String] ?? "",e[kCGWindowBounds as String] ?? "")}}' >"$ROOT/chrome-windows.txt"
cat "$ROOT/chrome-windows.txt"
if ! grep -q 'CHROME_WINDOW' "$ROOT/chrome-windows.txt";then say "CHROME_WINDOW=NOT_FOUND";exit 3;fi
screencapture -x "$ROOT/chrome-before.png" 2>/dev/null || true

"$BIN" --glass-preview >"$ROOT/app.log" 2>&1 &
APP_PID=$!
trap 'kill -TERM "$APP_PID" 2>/dev/null || true;kill -TERM "$CHROME_PID" 2>/dev/null || true' EXIT
sleep 4
kill -0 "$APP_PID"
say "APP_GLASS_PREVIEW=RUNNING"

cat >"$ROOT/click.swift" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation
let wins=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
guard let win=wins.first(where:{($0[kCGWindowName as String] as? String ?? "").contains("Glass Preview")}),
      let d=win[kCGWindowBounds as String] as? [String:Any],
      let r=CGRect(dictionaryRepresentation:d as CFDictionary) else {
    print("GLASS_WINDOW_NOT_FOUND")
    exit(3)
}
print("GLASS_RECT=\(r)")
let p=CGPoint(x:r.midX,y:r.minY+270)
print("SCROLL_BUTTON_CLICK=\(p)")
for t in [CGEventType.mouseMoved,.leftMouseDown,.leftMouseUp] {
    CGEvent(mouseEventSource:nil,mouseType:t,mouseCursorPosition:p,
            mouseButton:.left)?.post(tap:.cghidEventTap)
    Thread.sleep(forTimeInterval:0.16)
}
SWIFT
cat >"$ROOT/ax-press.swift" <<'SWIFT'
import AppKit
import ApplicationServices
import Foundation

let appPID=pid_t(Int(CommandLine.arguments[1]) ?? -1)
guard appPID>0 else { exit(2) }
let app=AXUIElementCreateApplication(appPID)
AXUIElementSetMessagingTimeout(app, 5)
var traversed=0
var found=0
var pressed=false
func attr(_ element:AXUIElement,_ name:CFString)->CFTypeRef? {
    var result:CFTypeRef?
    guard AXUIElementCopyAttributeValue(element,name,&result) == .success else {return nil}
    return result
}
func walk(_ element:AXUIElement,_ depth:Int) {
    guard depth<16, traversed<1200, !pressed else {return}
    traversed+=1
    let fields:[CFString]=[kAXRoleAttribute as CFString,kAXTitleAttribute as CFString,kAXDescriptionAttribute as CFString,kAXHelpAttribute as CFString]
    let labels=fields.compactMap { attr(element,$0) as? String }
    if labels.joined(separator:" ").contains("Tự cuộn toàn bộ trang") {
        found+=1
        let code=AXUIElementPerformAction(element,kAXPressAction as CFString)
        print("AX_SCROLL_BUTTON_MATCH role="+labels.joined(separator:" | "))
        print("AX_PRESS_STATUS=\(code.rawValue)")
        if code == .success {pressed=true; return}
    }
    if let children=attr(element,kAXChildrenAttribute as CFString) as? [AXUIElement] {
        for item in children { walk(item,depth+1) }
    }
}
walk(app,0)
print("AX_NODES=\(traversed) MATCHES=\(found) PRESSED=\(pressed)")
exit(pressed ? 0 : 4)
SWIFT
swiftc "$ROOT/ax-press.swift" -framework AppKit -o "$ROOT/ax-press"
if "$ROOT/ax-press" "$APP_PID" >"$ROOT/ax-press.log" 2>&1; then
  say "AX_SCROLL_BUTTON=PRESS_SUCCESS"
else
  say "AX_SCROLL_BUTTON=NOT_PRESSABLE_FALLBACK_QUARTZ"
  swiftc "$ROOT/click.swift" -framework AppKit -o "$ROOT/click"
  "$ROOT/click" >"$ROOT/click.log" 2>&1 || true
fi
cat "$ROOT/ax-press.log"
sleep 2
screencapture -x "$ROOT/scroll-modal.png" 2>/dev/null || true
osascript -e 'tell application "System Events" to tell process "ScreenShotQuick" to keystroke return' >"$ROOT/start.log" 2>&1 || true

PHOTO_DIR="$HOME/Desktop/Ảnh chụp màn hình"
for i in $(seq 1 28); do
  if find "$PHOTO_DIR" -maxdepth 1 -type f -name 'ChupManHinhEasy-TuCuon-*.png' -print -quit 2>/dev/null | grep -q .; then break; fi
  sleep 3
done
screencapture -x "$ROOT/after-scroll.png" 2>/dev/null || true
PHOTO="$(find "$PHOTO_DIR" -maxdepth 1 -type f -name 'ChupManHinhEasy-TuCuon-*.png' -print -quit 2>/dev/null || true)"
if [ -z "$PHOTO" ];then
  say "APP_AUTOSCROLL_CHROME=NOT_VERIFIED_NO_STITCHED_FILE"
else
  cp "$PHOTO" "$ROOT/chrome-scroll-actual.png"
  HEIGHT="$(sips -g pixelHeight "$PHOTO" | awk '/pixelHeight/ {print $2}')"
  WIDTH="$(sips -g pixelWidth "$PHOTO" | awk '/pixelWidth/ {print $2}')"
  say "AUTO_SCROLL_PNG_DIMENSIONS=${WIDTH}x${HEIGHT}"
  if ((HEIGHT>1500));then
    say "APP_AUTOSCROLL_CHROME=PASS_IMAGE_CREATED_HEIGHT_GT_1500"
  else
    say "APP_AUTOSCROLL_CHROME=NOT_VERIFIED_OUTPUT_TOO_SHORT"
  fi
fi
say "BROWSER_INTEL_QA_COMPLETE"
