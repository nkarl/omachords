import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property string status: "idle"
  property string detail: "Engine starts on first note"
  property bool ready: false
  property var pendingLines: []

  readonly property string binaryPath: decodeURIComponent(Qt.resolvedUrl("bin/chord-circle-engine").toString().replace(/^file:\/\//, ""))

  function queue(command) {
    var line = JSON.stringify(command) + "\n"
    if (root.ready && engineProcess.running) {
      engineProcess.write(line)
      return
    }
    var pending = root.pendingLines.slice(0)
    pending.push(line)
    root.pendingLines = pending
    if (!engineProcess.running) {
      root.status = "starting"
      root.detail = "Starting audio engine"
      engineProcess.running = true
    }
  }

  function flush() {
    if (!root.ready || !engineProcess.running)
      return
    for (var i = 0; i < root.pendingLines.length; i++)
      engineProcess.write(root.pendingLines[i])
    root.pendingLines = []
  }

  function setHeld(revision, notes) {
    root.queue({ v: 1, cmd: "set_held", revision: revision, notes: notes })
  }

  function audition(revision, notes, durationMs) {
    root.queue({ v: 1, cmd: "audition", revision: revision, notes: notes, duration_ms: durationMs })
  }

  function stop(revision) {
    if (engineProcess.running)
      root.queue({ v: 1, cmd: "stop", revision: revision })
  }

  function handleLine(line) {
    try {
      var message = JSON.parse(line)
      if (message.event === "ready") {
        root.ready = true
        root.status = "ready"
        root.detail = "Audio ready · " + message.rate + " Hz · " + message.channels + " channel" + (message.channels === 1 ? "" : "s")
        root.flush()
      } else if (message.event === "applied") {
        root.status = "playing"
      } else if (message.event === "error") {
        root.status = "error"
        root.detail = String(message.message || "Audio engine error")
      }
    } catch (error) {
      root.status = "error"
      root.detail = "Invalid engine response"
    }
  }

  property Process engineProcess: Process {
    command: [root.binaryPath]
    stdinEnabled: true
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.handleLine(line) }
    }
    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        if (line.length > 0) {
          root.status = "error"
          root.detail = line
        }
      }
    }
    onExited: function(exitCode) {
      root.ready = false
      root.status = exitCode === 0 ? "idle" : "error"
      root.detail = exitCode === 0 ? "Engine stopped" : "Engine exited with code " + exitCode
    }
  }

  Component.onDestruction: {
    if (engineProcess.running) {
      engineProcess.write(JSON.stringify({ v: 1, cmd: "shutdown" }) + "\n")
      engineProcess.signal(15)
    }
  }
}
