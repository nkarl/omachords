"""Audio-free child process for real EngineAdapter lifecycle tests."""

import json
import sys
import time

mode = sys.argv[1]
if mode == "hang":
    time.sleep(30)
    sys.exit(0)
if mode == "exit":
    sys.exit(2)
if mode == "malformed":
    print("invalid json", flush=True)
    time.sleep(30)
    sys.exit(0)

time.sleep(0.1)
print(json.dumps({"event": "ready", "rate": 48000, "channels": 2}), flush=True)
for line in sys.stdin:
    command = json.loads(line)
    if command["cmd"] == "shutdown":
        break
    print(json.dumps({"event": "applied", "command": command}), flush=True)
