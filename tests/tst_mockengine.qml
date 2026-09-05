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

  function test_auditionIsAtomic() {
    var command = engine.audition(7, [64, 67, 72], 900)
    compare(engine.commands.length, 2)
    compare(engine.commands[0].cmd, "start")
    compare(command.cmd, "audition")
    compare(command.revision, 7)
    compare(command.notes.length, 3)
    compare(command.notes[0], 64)
    compare(command.notes[1], 67)
    compare(command.notes[2], 72)
    compare(command.duration_ms, 900)
  }

  function test_seventhAuditionIsAtomic() {
    var command = engine.audition(9, [57, 60, 64, 67], 900)
    compare(engine.commands.length, 2)
    compare(command.cmd, "audition")
    compare(command.revision, 9)
    compare(command.notes.length, 4)
    compare(command.notes[0], 57)
    compare(command.notes[1], 60)
    compare(command.notes[2], 64)
    compare(command.notes[3], 67)
    compare(command.duration_ms, 900)
  }

  function test_stopAndShutdownFollowLifecycle() {
    engine.start()
    engine.stop(8)
    compare(engine.status, "stopped")
    engine.shutdown()
    compare(engine.running, false)
    compare(engine.commands[engine.commands.length - 1].cmd, "shutdown")
  }
}
