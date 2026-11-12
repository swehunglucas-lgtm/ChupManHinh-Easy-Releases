#!/usr/bin/env bash
set -euo pipefail
ROOT="$RUNNER_TEMP/intel15-gpu"
mkdir -p "$ROOT"
echo "ARCH=$(uname -m)" | tee "$ROOT/result.txt"
echo "OS=$(sw_vers -productVersion)" | tee -a "$ROOT/result.txt"
sysctl -n machdep.cpu.brand_string | tee "$ROOT/cpu.txt"
system_profiler SPDisplaysDataType >"$ROOT/display.txt" 2>&1 || true
test "$(uname -m)" = "x86_64"

cat >"$ROOT/MinimalCanvas.swift" <<'SWIFT'
import AppKit
import SwiftUI

@MainActor
@main
struct MinimalCanvas {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let view=NSHostingView(rootView:Canvas { context, size in
            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(.blue))
        })
        let win=NSWindow(contentRect:NSRect(x:0,y:0,width:480,height:320),
                         styleMask:[.titled,.closable],
                         backing:.buffered,defer:false)
        win.title="Independent SwiftUI Metal Baseline"
        win.contentView=view
        win.center()
        win.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps:true)
        app.run()
    }
}
SWIFT
swiftc -target x86_64-apple-macosx13.0 -parse-as-library -framework AppKit -framework SwiftUI \
    "$ROOT/MinimalCanvas.swift" -o "$ROOT/MinimalCanvas"
python3 - "$ROOT" <<'PY'
import pathlib,subprocess,sys,time
root=pathlib.Path(sys.argv[1])
p=subprocess.Popen([str(root/'MinimalCanvas')],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
time.sleep(7)
alive=p.poll() is None
if alive:
    p.terminate()
    try: out,err=p.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        p.kill();out,err=p.communicate()
else:
    out,err=p.communicate()
(root/'canvas-stdout.txt').write_bytes(out)
(root/'canvas-stderr.txt').write_bytes(err)
if b'Target device architecture is nil' in err:
    result='INDEPENDENT_SWIFTUI_METAL_ASSERTION_REPRODUCED'
elif alive:
    result='MINIMAL_SWIFTUI_CANVAS_SURVIVED_7_SECONDS'
else:
    result=f'MINIMAL_CANVAS_FAILED_OTHER_EXIT_{p.returncode}'
with (root/'result.txt').open('a') as f:f.write('METAL_BASELINE='+result+'\n')
print('METAL_BASELINE='+result)
print('MINIMAL_CANVAS_EXIT='+str(p.returncode))
print('MINIMAL_CANVAS_STDERR_TAIL='+err.decode('utf8','replace')[-450:])
PY
echo "INTEL15_ENVIRONMENT_PROBE_COMPLETE"
