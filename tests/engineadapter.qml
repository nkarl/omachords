import QtQuick
import QtTest
import "."

TestCase {
  id: testCase
  name: "EngineAdapter"
  property var engine: null
  property var received: []
  readonly property string fixture: decodeURIComponent(Qt.resolvedUrl("fixtures/engine.py").toString().replace(/^file:\/\//, ""))

  // Quickshell hosts its own QML plugins, but does not print QtTest's summary.
  onCompletedChanged: if (completed) console.log("ENGINE_ADAPTER_RESULT " + JSON.stringify({ passed: qtest_results.passCount, failed: qtest_results.failCount, skipped: qtest_results.skipCount }))

  Component { id: adapter; EngineAdapter {} }

  Connections {
    target: testCase.engine ? testCase.engine.engineProcess.stdout : null
    function onRead(line) {
      try {
        var message = JSON.parse(line)
        if (message.command)
          testCase.received = testCase.received.concat([message.command])
      } catch (error) {}
    }
  }

  function init() {
    received = []
    engine = adapter.createObject(testCase)
    engine.engineProcess.command = ["python3", fixture, "ready"]
    engine.startupTimer.interval = 2000
  }

  function cleanup() {
    if (engine.engineProcess.running) {
      engine.engineProcess.signal(9)
      tryCompare(engine.engineProcess, "running", false)
    }
    engine.destroy()
    engine = null
  }

  function test_coalescesAndFlushesLatestCommands() {
    for (var i = 0; i < 1000; i++) {
      engine.setHeld(i, [60 + i % 12])
      engine.audition(i, [64], 900)
    }
    compare(engine.pendingCommands.length, 2)
    tryCompare(engine, "ready", true)
    tryVerify(function() { return received.length === 2 })
    compare(received[0].cmd, "set_held")
    compare(received[0].revision, 999)
    compare(received[1].cmd, "audition")
    compare(received[1].revision, 999)
    compare(engine.pendingCommands.length, 0)
    compare(engine.startupTimer.running, false)
  }

  function test_stopCancelsStartupPlayback() {
    engine.setHeld(1, [60])
    engine.audition(2, [64], 900)
    engine.stop(3)
    compare(engine.pendingCommands.length, 0)
    tryCompare(engine, "ready", true)
    engine.setHeld(4, [67])
    tryVerify(function() { return received.length === 1 })
    compare(received[0].revision, 4)
    engine.stop(5)
    tryVerify(function() { return received.length === 2 })
    compare(received[1].cmd, "stop")
  }

  function test_releaseReplacesHeldNotesBeforeReadiness() {
    engine.stop(0)
    compare(engine.engineProcess.running, false)
    engine.setHeld(1, [60])
    engine.setHeld(2, [])
    engine.queue({ cmd: "unsupported" })
    compare(engine.pendingCommands.length, 1)
    tryCompare(engine, "ready", true)
    tryVerify(function() { return received.length === 1 })
    compare(received[0].revision, 2)
    compare(received[0].notes.length, 0)
  }

  function test_timeoutClearsQueueAndAllowsExplicitRetry() {
    engine.engineProcess.command = ["python3", fixture, "hang"]
    engine.startupTimer.interval = 100
    engine.setHeld(1, [60])
    tryCompare(engine, "status", "error")
    tryCompare(engine.engineProcess, "running", false)
    compare(engine.pendingCommands.length, 0)
    verify(engine.detail.indexOf("timed out") >= 0)
    engine.handleLine('{"event":"ready"}')
    compare(engine.ready, false)
    wait(150)
    compare(engine.engineProcess.running, false)
    engine.engineProcess.command = ["python3", fixture, "ready"]
    engine.startupTimer.interval = 2000
    engine.setHeld(2, [67])
    tryCompare(engine, "ready", true)
    tryVerify(function() { return received.length === 1 })
    compare(received[0].revision, 2)
  }

  function test_earlyExitClearsPendingCommands() {
    engine.engineProcess.command = ["python3", fixture, "exit"]
    engine.setHeld(1, [60])
    tryCompare(engine, "status", "error")
    compare(engine.pendingCommands.length, 0)
    compare(engine.startupTimer.running, false)
  }

  function test_invalidStartupResponseTerminatesChild() {
    engine.engineProcess.command = ["python3", fixture, "malformed"]
    engine.setHeld(1, [60])
    tryCompare(engine, "status", "error")
    tryCompare(engine.engineProcess, "running", false)
    compare(engine.pendingCommands.length, 0)
    compare(engine.detail, "Invalid engine startup response")
  }

  function test_missingBinaryCannotKeepPendingCommandsForever() {
    engine.engineProcess.command = [fixture + ".missing"]
    engine.startupTimer.interval = 100
    engine.setHeld(1, [60])
    tryCompare(engine, "status", "error")
    compare(engine.pendingCommands.length, 0)
    compare(engine.engineProcess.running, false)
  }
}
