"""Проверка настоящего procps: ps -Af и время контролируемого дочернего процесса."""
import argparse
import calendar
import json
import os
from pathlib import Path
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument("--package", type=Path, required=True)
parser.add_argument("--expect-proot", action="store_true")
parser.add_argument("--baseline", type=Path)
args = parser.parse_args()
package = args.package.resolve()
ps = str(package / "bin/ps")
env = {**os.environ, "LC_ALL": "C", "TZ": "UTC"}
baseline = None
if args.expect_proot:
    assert re.search(r"^btime\s+0$", Path("/proc/stat").read_text(), re.MULTILINE), "missing PRoot fixture"
if args.baseline:
    baseline = subprocess.run([str(args.baseline), "-Af"], capture_output=True, text=True, env=env, timeout=15)
    assert baseline.returncode != 0 and "Unable to get system boot time" in baseline.stderr

fixed = subprocess.run([ps, "-Af"], capture_output=True, text=True, env=env, timeout=15)
assert fixed.returncode == 0 and not fixed.stderr, (fixed.returncode, fixed.stderr)
child = subprocess.Popen(["sleep", "30"])
try:
    time.sleep(1.2)
    fields = Path("/proc", str(child.pid), "stat").read_text().rsplit(")", 1)[1].split()
    ticks = int(fields[19])
    hz = os.sysconf("SC_CLK_TCK")
    expected = time.time() - time.clock_gettime(time.CLOCK_BOOTTIME) + ticks / hz
    start = subprocess.check_output([ps, "-p", str(child.pid), "-o", "lstart="], text=True, env=env, timeout=15).strip()
    actual = calendar.timegm(time.strptime(start, "%a %b %d %H:%M:%S %Y"))
    assert abs(actual - expected) < 2, (actual, expected, start)
    elapsed = int(subprocess.check_output([ps, "-p", str(child.pid), "-o", "etimes="], text=True, env=env, timeout=15))
    age = time.clock_gettime(time.CLOCK_BOOTTIME) - ticks / hz
    assert abs(elapsed - age) < 2, (elapsed, age)
    uptime = subprocess.run([str(package / "bin/uptime")], capture_output=True, text=True, env=env, timeout=15)
    assert uptime.returncode == 0, (uptime.returncode, uptime.stderr)
    # Строки CMD остальных процессов не записываются в отчёт.
    print(json.dumps({
        "baseline_exit": baseline.returncode if baseline else None,
        "fixed_exit": fixed.returncode,
        "rows": max(0, len(fixed.stdout.splitlines()) - 1),
        "start_time_utc": start,
        "start_error_seconds": actual - expected,
        "elapsed_seconds": elapsed,
        "expected_elapsed_seconds": age,
        "uptime": uptime.stdout.strip(),
        "package": str(package),
    }))
finally:
    child.terminate()
    child.wait(timeout=5)
