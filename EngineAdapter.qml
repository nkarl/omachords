import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property string status: "idle"
  property string detail: "Engine starts on first note"
  property bool ready: false
  property var pendingCommands: []
  property string startupFailure: ""

  readonly property string binaryPath: decodeURIComponent(Qt.resolvedUrl("engine/target/release/omachords-engine").toString().replace(/^file:\/\//, ""))

  function queue(command) {
    if (command.cmd !== "set_held" && command.cmd !== "audition" && command.cmd !== "stop")
      return
    if (command.cmd === "stop" && !root.ready) {
      root.pendingCommands = []
      return
    }
    var line = JSON.stringify(command) + "\n"
    if (root.ready && engineProcess.running) {
      engineProcess.write(line)
      return
    }
    if (root.startupFailure && engineProcess.running)
      return
    // Before readiness, only the latest held state and audition are useful.
    var pending = root.pendingCommands.filter(function(value) { return value.cmd !== command.cmd })
    pending.push(command)
    root.pendingCommands = pending
    if (!engineProcess.running && !startupTimer.running) {
      root.startupFailure = ""
      root.status = "starting"
      root.detail = "Starting audio engine"
      startupTimer.start()
      engineProcess.running = true
    }
  }

  function flush() {
    if (!root.ready || !engineProcess.running)
      return
    for (var i = 0; i < root.pendingCommands.length; i++)
      engineProcess.write(JSON.stringify(root.pendingCommands[i]) + "\n")
    root.pendingCommands = []
  }

  function setHeld(revision, notes) {
    root.queue({ v: 1, cmd: "set_held", revision: revision, notes: notes })
  }

  function audition(revision, notes, durationMs) {
    root.queue({ v: 1, cmd: "audition", revision: revision, notes: notes, duration_ms: durationMs })
  }

  function stop(revision) {
    root.pendingCommands = []
    if (root.ready && engineProcess.running)
      root.queue({ v: 1, cmd: "stop", revision: revision })
  }

  function failStartup(message) {
    startupTimer.stop()
    root.startupFailure = message
    root.ready = false
    root.pendingCommands = []
    root.status = "error"
    root.detail = message
    // An engine that never becomes ready must not remain stuck in the background.
    if (engineProcess.running)
      engineProcess.signal(9)
  }

  property Timer startupTimer: Timer {
    interval: 5000
    onTriggered: root.failStartup("Audio engine startup timed out; play a note to retry")
  }

  function handleLine(line) {
    if (root.startupFailure || !engineProcess.running)
      return
    try {
      var message = JSON.parse(line)
      if (message.event === "ready") {
        startupTimer.stop()
        root.ready = true
        root.status = "ready"
        root.detail = "Audio ready · " + message.rate + " Hz · " + message.channels + " channel" + (message.channels === 1 ? "" : "s")
        root.flush()
      } else if (message.event === "applied") {
        root.status = "playing"
        root.detail = "Audio active"
      } else if (message.event === "error") {
        if (!root.ready) {
          root.failStartup(String(message.message || "Audio engine startup failed"))
          return
        }
        root.status = "error"
        root.detail = String(message.message || "Audio engine error")
      }
    } catch (error) {
      if (!root.ready) {
        root.failStartup("Invalid engine startup response")
        return
      }
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
        if (line.length > 0 && !root.startupFailure) {
          root.status = "error"
          root.detail = line
        }
      }
    }
    onExited: function(exitCode) {
      startupTimer.stop()
      root.ready = false
      root.pendingCommands = []
      if (root.startupFailure)
        return
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
