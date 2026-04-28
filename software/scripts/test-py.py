#!/usr/bin/env python3
print("Python test - START")
import subprocess
print("Testing subprocess...")
result = subprocess.run("node --version", capture_output=True, text=True, shell=True)
print("Node version:", result.stdout.strip())
print("Python test - END")
