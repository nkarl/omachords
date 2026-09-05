import QtQuick

QtObject {
  id: root

  property bool running: false
  property var commands: []
  property string status: "deferred"

  signal commandRecorded(var command)

  function record(command) {
    var next = root.commands.slice(0)
    next.push(command)
    root.commands = next
    root.commandRecorded(command)
    return command
  }

  function start() {
    root.running = true
    root.status = "ready"
    return root.record({ v: 1, cmd: "start" })
  }

  function setChord(revision, pitches, bass) {
    if (!root.running)
      root.start()
    root.status = "applied"
    return root.record({
      v: 1,
      cmd: "set_chord",
      revision: revision,
      pitches: pitches.slice(0),
      bass: bass
    })
  }

  function stopChord(revision) {
    root.status = "stopped"
    return root.record({ v: 1, cmd: "stop", revision: revision })
  }

  function shutdown() {
    root.running = false
    root.status = "shutdown"
    return root.record({ v: 1, cmd: "shutdown" })
  }
}
