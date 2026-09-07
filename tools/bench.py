"""Run the AIR benchmark and save raw samples plus a readable summary."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import time
import uuid


def air_prefix(command):
    if "AIR_PATH_PREFIX" in os.environ:
        return os.environ["AIR_PATH_PREFIX"]
    # Match the Wine shell wrapper used by the AIR SDK on Linux. Native AIR needs no prefix.
    executable = shutil.which(command[0])
    if executable and os.name != "nt":
        with open(executable, "rb") as source:
            wrapper = source.read(8192).lower()
        if wrapper.startswith(b"#!") and b"wine" in wrapper:
            return "Z:"
    return ""


def summary(result):
    lines = [
        f"AIR {result['runtime']} | {result['runtimeOS']}",
        f"{result['count']} messages/workload; {result['samples']} samples; target {result['targetMs']} ms/sample.",
        "Rates use median time. MB = 1,000,000 bytes; sizes are averages per complete root message.",
        "View MB/s is equivalent full-message throughput, not bytes actually read.",
        "AMF3/JSON decode to plain objects; FlatBuffers unpacks to generated typed objects.",
    ]
    workload = None
    for row in result["results"]:
        if row["workload"] != workload:
            workload = row["workload"]
            lines += ["", workload, f"{'Format / operation':34} {'B/msg':>9} {'ops/s':>12} {'MB/s':>10} {'ms min/med/max':>20}"]
        timings = row["milliseconds"]
        label = f"{row['format']} {row['operation']}"
        lines.append(f"{label:34} {row['bytesPerMessage']:9.1f} {row['opsPerSecond']:12,.0f} "
                     f"{row['mbPerSecond']:10.2f} {min(timings):5.0f}/{row['medianMs']:5.0f}/{max(timings):5.0f}")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=5, help="odd sample count, 3..21 (default: 5)")
    parser.add_argument("--sample-ms", type=int, default=150, help="target milliseconds per sample, 50..2000 (default: 150)")
    parser.add_argument("--count", type=int, default=64, help="distinct deterministic messages, 16..256 (default: 64)")
    parser.add_argument("--build-dir", type=Path, default=Path("runtime/bin/bench"), help="compiled benchmark directory")
    args = parser.parse_args()
    if not (3 <= args.samples <= 21 and args.samples % 2 and 50 <= args.sample_ms <= 2000 and 16 <= args.count <= 256):
        parser.error("invalid samples, sample-ms, or count")
    root = Path(__file__).resolve().parent.parent
    build = (root / args.build_dir).resolve()
    if not (build / "bench.swf").is_file():
        parser.error("compile the benchmark first with just build-bench")
    token = uuid.uuid4().hex
    work = root / "runtime/bin" / ("bench-" + token)
    work.mkdir(parents=True)
    descriptor = (root / "runtime/bench/application.xml").read_text().replace(
        "<id>as3flatbuffers.bench</id>", f"<id>as3flatbuffers.bench.p{token}</id>")
    # Keep descriptors unique; the SWF lives in the shared build root.
    app = work / "application.xml"
    app.write_text(descriptor)
    command = shlex.split(os.environ.get("ADL", "adl"))
    if not command or not shutil.which(command[0]):
        parser.error("ADL is unavailable; install the AIR SDK or set ADL to its launcher")
    prefix = air_prefix(command)
    command += ["-nodebug", str(app.relative_to(root)), str(build.relative_to(root)), "--",
                prefix + work.as_posix(), str(args.count), str(args.samples), str(args.sample_ms)]
    timeout = 120 + 60 * args.samples * args.sample_ms / 1000 * 3
    print(f"Running AIR benchmark; artifacts: {work.relative_to(root)}", flush=True)
    with (work / "adl.log").open("w") as log:
        process = subprocess.Popen(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
        start = time.monotonic()
        completed = None
        try:
            while process.poll() is None:
                if time.monotonic() - start > timeout:
                    raise TimeoutError(f"AIR benchmark timed out; see {work / 'adl.log'}")
                progress = work / "progress.json"
                if progress.exists():
                    try:
                        name = json.loads(progress.read_text())["completed"]
                        if name != completed:
                            print(f"Completed {name}.", flush=True)
                            completed = name
                    except (ValueError, KeyError):
                        pass  # The app may be writing this file right now.
                time.sleep(0.25)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
    result_file = work / "result.json"
    if not result_file.exists():
        raise RuntimeError(f"AIR produced no result (exit {process.returncode}); see {work / 'adl.log'}")
    result = json.loads(result_file.read_text())
    if process.returncode or not result.get("ok"):
        raise RuntimeError(f"AIR benchmark failed: {result}; logs: {work}")
    if len(result["results"]) not in (45, 60):
        raise RuntimeError("Incomplete benchmark results")
    metadata = build / "metadata.json"
    if metadata.exists():
        result["comparisonBuild"] = json.loads(metadata.read_text())
    result["host"] = platform.platform()
    result["utc"] = datetime.now(timezone.utc).isoformat()
    result["compilerFlags"] = "optimize=true strict=true inline=true debug=false"
    result["gitCommit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    result["gitDirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip())
    result_file.write_text(json.dumps(result, indent=2) + "\n")
    report = summary(result)
    (work / "summary.txt").write_text(report)
    print(report, end="")
    print(f"Raw samples: {result_file.relative_to(root)}")


if __name__ == "__main__":
    main()
