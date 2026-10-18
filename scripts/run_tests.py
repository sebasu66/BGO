"""Runs the headless Godot tests and fails on anything suspicious.

A green run needs three things: the PASSED line, no SCRIPT ERROR and no
compile failure. The Godot runner alone can print PASSED while a script that
failed to compile was silently skipped, so this wrapper reads both streams.

Usage: python scripts/run_tests.py [path-to-godot-console-exe]
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_GODOT = r"C:\DEV\.tools\godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe"
TIME_LIMIT_SECONDS = 120  # a script error leaves the Godot runner hanging, so keep this short
BAD_MARKERS = ("SCRIPT ERROR", "Compile Error", "Compilation failed", "BGO TESTS FAILED")


def run_godot(godot: str) -> tuple[int, str]:
    command = [godot, "--headless", "--path", str(ROOT), "--script", "res://tests/test_runner.gd"]
    try:
        done = subprocess.run(
            command, capture_output=True, text=True, timeout=TIME_LIMIT_SECONDS, errors="replace"
        )
    except subprocess.TimeoutExpired:
        return 124, "TIMEOUT: the tests did not finish in time"
    return done.returncode, done.stdout + "\n" + done.stderr


def main() -> int:
    godot = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_GODOT
    code, output = run_godot(godot)
    lines = output.splitlines()
    problems = [line for line in lines if any(marker in line for marker in BAD_MARKERS)]
    failed_checks = [line for line in lines if line.startswith("FAIL")]
    passed = [line for line in lines if line.startswith("BGO TESTS PASSED")]
    for line in (failed_checks + problems)[:30]:
        print(line)
    if code != 0 or problems or failed_checks or not passed:
        print(f"TESTS NOT GREEN (exit code {code}, problems {len(problems)}, failed {len(failed_checks)})")
        return 1
    print(passed[-1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
