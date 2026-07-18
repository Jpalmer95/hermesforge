#!/usr/bin/env python3
"""HermesForge QA harness v0 — headless Godot verification.

Usage:
  python qa/run.py <target> [--godot PATH] [--timeout SECS] [--keep]

<target> is either:
  - a project dir containing project.godot (e.g. templates/base), or
  - a module test dir (e.g. modules/terrain/tests/<test>) — resolved later.

What it does (v0):
  1. Locates the Godot binary (arg, env GODOT_BIN, then PATH).
  2. Runs `godot --headless --path <project> --quit-after N` to import the
     project and open its main scene briefly.
  3. Captures stdout/stderr; FAILs on Godot script errors or missing addons.
  4. Saves a screenshot if the project defines qa/screenshot.gd (autoload hook)
     — templates/base ships one. Exit 0 = pass, non-zero = fail.

Later phases add: screenshot diffing against tests/expect/, perf budgets
(draw calls, physics tick ms), and scene-tree structural assertions.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ERROR_PATTERNS = [
    r"SCRIPT ERROR",
    r"Parse Error",
    r"Cannot open file.*addon",
    r"Failed loading resource",
    r"Nonexistent function",
    r"Can't load extension",
    r"ERROR:.*required",
]


def find_godot(arg_path: str | None) -> str | None:
    for cand in [arg_path, os.environ.get("GODOT_BIN"), "godot"]:
        if not cand:
            continue
        resolved = shutil.which(cand) if not os.path.isabs(cand) else cand
        if resolved and Path(resolved).exists():
            return resolved
    return None


def resolve_target(target: str) -> Path:
    p = Path(target)
    if not p.is_absolute():
        p = ROOT / target
    if (p / "project.godot").exists():
        return p
    if (p / "scene.tscn").exists():
        # module test dir — use base template as host project (future: inject scene)
        base = ROOT / "templates" / "base"
        if (base / "project.godot").exists():
            return base
    print(f"FAIL: cannot resolve target {target} (no project.godot found)", file=sys.stderr)
    sys.exit(2)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target")
    ap.add_argument("--godot", default=None)
    ap.add_argument("--timeout", type=int, default=90)
    ap.add_argument("--quit-after", type=int, default=120,
                    help="frames to run before quitting (lets scene boot)")
    ap.add_argument("--keep", action="store_true", help="keep temp output dir")
    args = ap.parse_args()

    godot = find_godot(args.godot)
    if not godot:
        print("FAIL: Godot binary not found (set GODOT_BIN or --godot)", file=sys.stderr)
        return 2

    project = resolve_target(args.target)
    outdir = Path(tempfile.mkdtemp(prefix="hermesforge-qa-"))
    log_path = outdir / "godot.log"

    cmd = [
        godot, "--headless", "--path", str(project),
        "--quit-after", str(args.quit_after),
    ]
    # Import pass first: GDExtensions/plugins only register after the .godot/
    # import cache exists. Running the scene on a fresh checkout without this
    # gives false "class not found" results.
    import_cmd = [godot, "--headless", "--path", str(project), "--import"]
    print(f"QA: {godot}")
    print(f"QA: project = {project}")
    print("QA: import pass...")
    try:
        subprocess.run(import_cmd, capture_output=True, text=True,
                       timeout=args.timeout)
    except subprocess.TimeoutExpired:
        print("QA: import pass timed out (continuing to scene run)")
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              timeout=args.timeout)
        timed_out = False
    except subprocess.TimeoutExpired as e:
        proc = e
        timed_out = True
    elapsed = time.time() - t0

    def _text(value) -> str:
        if value is None:
            return ""
        if isinstance(value, bytes):
            return value.decode("utf-8", errors="replace")
        return str(value)

    stdout = _text(getattr(proc, "stdout", ""))
    stderr = _text(getattr(proc, "stderr", ""))
    log_path.write_text(stdout + "\n--- STDERR ---\n" + stderr, encoding="utf-8")

    errors = []
    for pat in ERROR_PATTERNS:
        for line in (stdout + "\n" + stderr).splitlines():
            if re.search(pat, line):
                errors.append(line.strip())
    if timed_out:
        errors.append(f"Timed out after {args.timeout}s (possible hang/crash)")

    print(f"QA: ran {elapsed:.1f}s, log at {log_path}")
    if errors:
        print("QA: FAIL")
        for e in errors[:20]:
            print(f"  ! {e}")
        if not args.keep:
            pass  # keep log regardless on failure
        return 1
    print("QA: PASS")
    if not args.keep:
        shutil.rmtree(outdir, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
