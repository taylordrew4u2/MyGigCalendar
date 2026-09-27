#!/usr/bin/env python3
"""Drive SEE ME LIVE in a booted iOS Simulator with idb and capture screenshots.

Usage: drive.py <simulator-udid> <output-dir>

Each screenshot is saved in <output-dir> as a full PNG and a small JPEG.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

UDID, OUT = sys.argv[1], Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
BUNDLE_ID = "comedy.SEE-ME-LIVE"


def run(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True)


def idb(*args):
    """Runs an idb command, retrying briefly; returns stdout or "" on failure."""
    for attempt in range(3):
        result = run("idb", *args, "--udid", UDID, check=False)
        if result.returncode == 0:
            return result.stdout
        print(f"!! idb {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()[-400:]}")
        time.sleep(1.5)
    return ""


def elements():
    out = idb("ui", "describe-all", "--json")
    if not out.strip():
        return []
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return [json.loads(line) for line in out.splitlines() if line.strip()]


def labels():
    return [e.get("AXLabel") or e.get("AXValue") or "" for e in elements()]


def find(*needles, kind=None):
    for element in elements():
        text = f"{element.get('AXLabel') or ''} {element.get('AXValue') or ''}"
        if kind and element.get("type") != kind:
            continue
        if any(n.lower() in text.lower() for n in needles):
            return element
    return None


def tap(*needles, kind=None, wait=1.2):
    element = find(*needles, kind=kind)
    if element is None:
        print(f"!! no element matching {needles}; on screen: {labels()}")
        return False
    frame = element["frame"]
    x = frame["x"] + frame["width"] / 2
    y = frame["y"] + frame["height"] / 2
    print(f"-> tap {needles} at ({x:.0f}, {y:.0f})")
    idb("ui", "tap", str(int(x)), str(int(y)))
    time.sleep(wait)
    return True


SPRINGBOARD_LABELS = {"Safari", "Messages", "Fitness"}
problems = []


def shot(name):
    png = OUT / f"{name}.png"
    jpg = OUT / f"{name}.jpg"
    run("xcrun", "simctl", "io", UDID, "screenshot", str(png))
    run("sips", "-Z", "560", "-s", "format", "jpeg", "-s", "formatOptions", "45",
        str(png), "--out", str(jpg))
    current = [l for l in labels() if l]
    print(f"[{name}] labels: {current[:25]}", flush=True)
    if SPRINGBOARD_LABELS.issubset(current):
        problems.append(f"{name}: app is not in the foreground (crashed or exited)")


def launch():
    run("xcrun", "simctl", "launch", UDID, BUNDLE_ID)


# 1. Cold launch: splash, then onboarding.
launch()
time.sleep(1.0)
shot("01-splash")
time.sleep(3.0)
shot("02-onboarding")
for _ in range(8):
    if tap("Start using My Gig Calendar", wait=2.0):
        break
    if not tap("Continue", wait=1.0):
        break
shot("03-home-empty")

# 2. Open the editor and cancel with no changes: should close with no toast.
tap("Add show", "Add a show", wait=1.5)
shot("04-editor-new")
tap("Cancel", wait=1.5)
shot("05-after-clean-cancel")

# 3. Type a title, then Cancel: should ask to discard.
tap("Add show", "Add a show", wait=1.5)
if tap("Show title", kind="TextField", wait=0.5) or tap("Show title", wait=0.5):
    idb("ui", "text", "Open Mic Night")
    time.sleep(0.8)
shot("06-editor-typed")
tap("Cancel", wait=1.2)
shot("07-discard-prompt")
tap("Keep Editing", wait=1.0)

# 4. Save: should close and toast "Show saved", and the gig should list.
tap("Save Show", wait=3.0)
shot("08-after-save")
time.sleep(2.5)
shot("09-home-with-gig")

# 5. Open the saved gig.
tap("Open Mic Night", wait=1.5)
shot("10-detail")

if problems:
    print("\nPROBLEMS:\n" + "\n".join(problems))
    sys.exit(1)
print("\nAll steps ran with the app in the foreground.")
