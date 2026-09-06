"""Build the optional AS3PB comparison without modifying its checkout."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


def run(command, cwd):
    subprocess.run([str(arg) for arg in command], cwd=cwd, check=True)


def main():
    root = Path(__file__).resolve().parent.parent
    configured = os.environ.get("AS3PB_ROOT")
    candidates = [Path(configured)] if configured else [root.parent / "as3pb", root.parent / "as3pb-conformance/as3pb"]
    source = next((path.resolve() for path in candidates if (path / "cmd/protoc-gen-as3").is_dir()), None)
    if source is None:
        raise SystemExit("Set AS3PB_ROOT to an AS3PB checkout containing cmd/protoc-gen-as3 and runtime/src.")
    protoc = os.environ.get("PROTOC") or shutil.which("protoc")
    if not protoc:
        candidate = source.parent / "tools/protobuf-build/protoc"
        if candidate.is_file():
            protoc = str(candidate)
    if not protoc:
        raise SystemExit("Set PROTOC to a protoc compiler executable.")
    protoc_command = shlex.split(protoc)
    build = root / "runtime/bin/bench-as3pb"
    generated = build / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    plugin = build / ("protoc-gen-as3.exe" if os.name == "nt" else "protoc-gen-as3")
    run(["go", "build", "-o", plugin, "./cmd/protoc-gen-as3"], source)
    schema = root / "runtime/bench/as3pb"
    run([*protoc_command, f"--plugin=protoc-gen-as3={plugin}", f"--as3_out={generated}", f"-I{schema}", schema / "bench.proto"], root)
    compiler = shlex.split(os.environ.get("AMXMLC", "amxmlc"))
    run([*compiler, "-define+=COMPILE::JS,false", "-source-path", root / "runtime/src",
         "-source-path", root / "runtime/bench/src", "-source-path", root / "runtime/bench/generated",
         "-source-path", root / "runtime/bench/as3pb/src", "-source-path", source / "runtime/src",
         "-source-path", generated, f"-output={build / 'bench.swf'}", "-optimize=true",
         "-compiler.strict=true", "-compiler.inline=true", "-debug=false", root / "runtime/bench/src/Main.as"], root)
    metadata = {
        "as3pbRoot": str(source),
        "as3pbCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True).strip(),
        "as3pbDirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=source, text=True).strip()),
        "protoc": subprocess.check_output([*protoc_command, "--version"], text=True).strip(),
    }
    (build / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
    run([sys.executable, root / "tools/bench.py", "--build-dir", build, *sys.argv[1:]], root)


if __name__ == "__main__":
    main()
