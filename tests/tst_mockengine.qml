import QtQuick
import QtTest
import ".."

TestCase {
  name: "MockEngine"

  MockEngine {
    id: engine
  }

  function init() {
    engine.running = false
    engine.commands = []
    engine.status = "deferred"
  }

  function test_setChordIsAtomic() {
    var command = engine.setChord(7, [0, 4, 7], 4)
    compare(engine.commands.length, 2)
    compare(engine.commands[0].cmd, "start")
    compare(command.cmd, "set_chord")
    compare(command.revision, 7)
    compare(command.pitches.length, 3)
    compare(command.pitches[0], 0)
    compare(command.pitches[1], 4)
    compare(command.pitches[2], 7)
    compare(command.bass, 4)
  }

  function test_stopAndShutdownFollowLifecycle() {
    engine.start()
    engine.stopChord(8)
    compare(engine.status, "stopped")
    engine.shutdown()
    compare(engine.running, false)
    compare(engine.commands[engine.commands.length - 1].cmd, "shutdown")
  }
}
