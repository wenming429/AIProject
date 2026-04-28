#!/usr/bin/env python3
# -*- coding: utf-8 -*-
print("=" * 50)
print("  LumenIM Build Environment Check")
print("=" * 50)
print("")

import subprocess
import sys
from pathlib import Path

# 绝对路径
PROJECT_ROOT = Path("d:/学习资料/AI_Projects/LumenIM/front")

def run_cmd(cmd, timeout=10):
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=True
        )
        output = (result.stdout + result.stderr).strip()
        return True, output[:100] if output else "OK"
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except FileNotFoundError:
        return False, "Not Found"
    except Exception as e:
        return False, str(e)[:50]

results = []

# [1] Node.js
print("[1] Node.js ... ", end="")
sys.stdout.flush()
found, version = run_cmd("node --version")
if found:
    print("OK - " + version)
    results.append(True)
else:
    print("FAIL - " + version)
    results.append(False)

# [2] npm
print("[2] npm ..... ", end="")
sys.stdout.flush()
found, version = run_cmd("npm --version")
if found:
    print("OK - " + version)
    results.append(True)
else:
    print("FAIL - " + version)
    results.append(False)

# [3] Rust
print("[3] Rust ... ", end="")
sys.stdout.flush()
found, version = run_cmd("rustc --version")
if found:
    print("OK - " + version)
    results.append(True)
else:
    print("FAIL - " + version)
    results.append(False)

# [4] Cargo
print("[4] Cargo .. ", end="")
sys.stdout.flush()
found, version = run_cmd("cargo --version")
if found:
    print("OK - " + version)
    results.append(True)
else:
    print("FAIL - " + version)
    results.append(False)

# [5] Tauri CLI
print("[5] Tauri .. ", end="")
sys.stdout.flush()
found, version = run_cmd("npx tauri --version")
if found:
    print("OK - " + version)
    results.append(True)
else:
    print("FAIL - Not Installed")
    results.append(False)

# [6] Project Files
print("")
print("[6] Project Files:")
print(f"    Project Root: {PROJECT_ROOT}")

files = [
    ("package.json", PROJECT_ROOT / "package.json"),
    ("vite.config.ts", PROJECT_ROOT / "vite.config.ts"),
    ("tauri.conf.json", PROJECT_ROOT / "src-tauri" / "tauri.conf.json"),
    ("Cargo.toml", PROJECT_ROOT / "src-tauri" / "Cargo.toml"),
    ("node_modules", PROJECT_ROOT / "node_modules"),
]

all_ok = True
for name, path in files:
    print(f"    {name} ... ", end="")
    sys.stdout.flush()
    if path.exists():
        print("OK")
    else:
        print("MISSING")
        all_ok = False

results.append(all_ok)

# Summary
print("")
print("=" * 50)
print("  Result Summary")
print("=" * 50)

passed = sum(results)
total = len(results)

if passed == total:
    print(f"  PASS ({passed}/{total})")
    print("")
    print("  Ready to build!")
    print("  Usage: python build.py local  # Local Dev")
    print("         python build.py test   # Test Build")
    print("         python build.py prod  # Production")
else:
    print(f"  FAIL ({passed}/{total})")
    print("")
    print("  Please install missing dependencies")
