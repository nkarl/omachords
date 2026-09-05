import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int rootIndex: 0
  property int qualityIndex: 0
  property int inversionIndex: 0
  property int revision: 0
  property var heldKeys: ({})
  property var heldPitches: []
  property int heldBass: -1
  property bool keyboardMode: false
  property string mockStatus: "Engine deferred · Play previews the command"

  readonly property color foreground: Color.foreground

  readonly property var pianoNotes: [
    { note: "C4", midi: 60, key: Qt.Key_A }, { note: "C#4", midi: 61, key: Qt.Key_W },
    { note: "D4", midi: 62, key: Qt.Key_S }, { note: "D#4", midi: 63, key: Qt.Key_E },
    { note: "E4", midi: 64, key: Qt.Key_D }, { note: "F4", midi: 65, key: Qt.Key_F },
    { note: "F#4", midi: 66, key: Qt.Key_T }, { note: "G4", midi: 67, key: Qt.Key_G },
    { note: "G#4", midi: 68, key: Qt.Key_Y }, { note: "A4", midi: 69, key: Qt.Key_H },
    { note: "A#4", midi: 70, key: Qt.Key_U }, { note: "B4", midi: 71, key: Qt.Key_J },
    { note: "C5", midi: 72, key: Qt.Key_K }, { note: "C#5", midi: 73, key: Qt.Key_O },
    { note: "D5", midi: 74, key: Qt.Key_L }, { note: "D#5", midi: 75, key: Qt.Key_P },
    { note: "E5", midi: 76, key: Qt.Key_Semicolon }, { note: "F5", midi: 77, key: Qt.Key_Apostrophe },
    { note: "F#5", midi: 78, key: Qt.Key_BracketLeft }, { note: "G5", midi: 79, key: Qt.Key_Z },
    { note: "G#5", midi: 80, key: Qt.Key_BracketRight }, { note: "A5", midi: 81, key: Qt.Key_X },
    { note: "A#5", midi: 82, key: Qt.Key_Backslash }, { note: "B5", midi: 83, key: Qt.Key_C },
    { note: "C6", midi: 84, key: Qt.Key_V }
  ]
  readonly property var selectedChord: Model.chord(root.rootIndex, root.qualityIndex, root.inversionIndex)
  readonly property var displayPitches: root.keyboardMode ? root.heldPitches : root.selectedChord.pitches
  readonly property int displayBass: root.keyboardMode ? root.heldBass : root.selectedChord.bass
  readonly property var displayTriad: root.keyboardMode ? Model.identifyTriad(root.heldPitches, root.heldBass) : root.selectedChord
  readonly property string displayLabel: root.keyboardMode ? (root.displayTriad ? root.displayTriad.label : root.heldPitches.length === 0 ? "No notes" : root.heldPitches.length + (root.heldPitches.length === 1 ? " note" : " notes")) : root.selectedChord.label
  readonly property string displayNoteNames: root.keyboardMode ? (root.displayTriad ? root.displayTriad.noteNames : root.heldPitches.length === 0 ? "Press a piano key" : Model.pitchSetNames(root.heldPitches)) : root.selectedChord.noteNames
  readonly property color gridColor: Util.alpha(root.foreground, 0.30)
  readonly property color quietColor: Util.alpha(root.foreground, 0.16)
  readonly property color activeColor: Color.accent
  readonly property var primaryKeyLabels: ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J"]

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.releaseAllKeys()
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "local.chord-circle")
  }

  function toggle() {
    if (root.opened)
      root.dismiss()
    else
      root.open("{}")
  }

  function setSelection(nextRoot, nextQuality, nextInversion) {
    var normalizedRoot = Model.wrap(nextRoot, Model.FIFTHS.length)
    var normalizedQuality = Model.wrap(nextQuality, Model.QUALITIES.length)
    var normalizedInversion = Model.wrap(nextInversion, Model.INVERSIONS.length)
    if (normalizedRoot === root.rootIndex && normalizedQuality === root.qualityIndex && normalizedInversion === root.inversionIndex)
      return

    root.rootIndex = normalizedRoot
    root.qualityIndex = normalizedQuality
    root.inversionIndex = normalizedInversion
    root.revision += 1
    graph.requestPaint()
  }

  function selectRoot(index) {
    root.leaveKeyboardMode()
    root.setSelection(index, root.qualityIndex, root.inversionIndex)
  }

  function selectQuality(index) {
    root.leaveKeyboardMode()
    root.setSelection(root.rootIndex, index, root.inversionIndex)
  }

  function selectInversion(index) {
    root.leaveKeyboardMode()
    root.setSelection(root.rootIndex, root.qualityIndex, index)
  }

  function leaveKeyboardMode() {
    root.keyboardMode = false
    root.releaseAllKeys()
    graph.requestPaint()
  }

  function playMock() {
    var pitches = root.displayPitches
    engine.setChord(root.revision, pitches, root.displayBass)
    root.mockStatus = "Queued " + root.displayLabel + " · " + root.displayNoteNames
    playFlash.restart()
  }

  function pianoNoteForKey(key) {
    for (var i = 0; i < root.pianoNotes.length; i++)
      if (root.pianoNotes[i].key === key)
        return root.pianoNotes[i]
    return null
  }

  function rebuildHeldState(nextKeys) {
    var entries = []
    for (var key in nextKeys)
      entries.push(nextKeys[key])
    var state = Model.heldPitchState(entries)

    root.heldKeys = nextKeys
    root.heldPitches = state.pitches
    root.heldBass = state.bass
    root.revision += 1
    if (state.pitches.length > 0) {
      engine.setChord(root.revision, state.pitches, root.heldBass)
      var identified = Model.identifyTriad(state.pitches, root.heldBass)
      root.mockStatus = "Held " + (identified ? identified.label : Model.pitchSetNames(state.pitches))
    } else {
      engine.stopChord(root.revision)
      root.mockStatus = "All keys released"
    }
    graph.requestPaint()
    return state
  }

  function updatePianoKey(key, pressed, autoRepeat) {
    var note = root.pianoNoteForKey(key)
    var next = Model.updateHeldKeys(root.heldKeys, key, note, pressed, autoRepeat)
    if (next === root.heldKeys)
      return false
    root.keyboardMode = true
    root.rebuildHeldState(next)
    return true
  }

  function releaseAllKeys() {
    if (Object.keys(root.heldKeys).length === 0)
      return
    root.rebuildHeldState({})
  }

  function nodeActive(pitch) {
    return Model.contains(root.displayPitches, pitch)
  }

  onSelectedChordChanged: graph.requestPaint()
  onHeldPitchesChanged: graph.requestPaint()
  onKeyboardModeChanged: graph.requestPaint()
  onOpenedChanged: if (!root.opened) root.releaseAllKeys()

  MockEngine {
    id: engine
  }

  Timer {
    id: playFlash
    interval: 1200
    onTriggered: root.mockStatus = "Engine deferred · Play previews the command"
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "chord-circle"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: Math.min(window.screen.width * 0.84, Style.space(920))
      height: Math.min(window.screen.height * 0.90, Style.space(980))
      radius: Math.max(Style.cornerRadius, Style.space(12))
      color: Color.popups.background
      border.color: Color.popups.border
      border.width: 1

      MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) { mouse.accepted = true }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
          event.accepted = true
          return
        }
        if (root.pianoNoteForKey(event.key)) {
          root.updatePianoKey(event.key, true, event.isAutoRepeat)
          event.accepted = true
          return
        }
      }

      Keys.onReleased: function(event) {
        if (root.pianoNoteForKey(event.key)) {
          root.updatePianoKey(event.key, false, event.isAutoRepeat)
          event.accepted = true
        }
      }

      Column {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(28)
        spacing: Style.space(14)

        Text {
          width: parent.width
          text: "CHORD CIRCLE"
          color: root.foreground
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.5
          horizontalAlignment: Text.AlignHCenter
        }

        Item {
          id: ring
          width: parent.width
          height: Math.min(width, card.height - Style.space(300))
          property int hoverIndex: -1
          readonly property real cx: width / 2
          readonly property real cy: height / 2
          readonly property real graphRadius: Math.min(width, height) / 2 - Style.space(48)

          Canvas {
            id: graph
            anchors.fill: parent

            function drawEdges(ctx, list, color, width) {
              ctx.strokeStyle = color
              ctx.lineWidth = width
              ctx.lineCap = "round"
              for (var i = 0; i < list.length; i++) {
                var aIndex = Model.sectorIndexForPitch(list[i].a)
                var bIndex = Model.sectorIndexForPitch(list[i].b)
                ctx.beginPath()
                ctx.moveTo(Model.polarX(ring.cx, ring.graphRadius, Model.sectorMidDeg(aIndex)), Model.polarY(ring.cy, ring.graphRadius, Model.sectorMidDeg(aIndex)))
                ctx.lineTo(Model.polarX(ring.cx, ring.graphRadius, Model.sectorMidDeg(bIndex)), Model.polarY(ring.cy, ring.graphRadius, Model.sectorMidDeg(bIndex)))
                ctx.stroke()
              }
            }

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              ctx.strokeStyle = root.quietColor
              ctx.lineWidth = 1.5
              ctx.beginPath()
              ctx.arc(ring.cx, ring.cy, ring.graphRadius, 0, Math.PI * 2)
              ctx.stroke()
              drawEdges(ctx, Model.edges(root.displayPitches), root.activeColor, 3)
            }
          }

          Repeater {
            model: Model.FIFTHS.length
            delegate: Rectangle {
              required property int index
              readonly property var note: Model.noteAt(index)
              readonly property bool selectedRoot: !root.keyboardMode && index === root.rootIndex
              readonly property bool active: root.nodeActive(note.pitch)
              width: Style.space(64)
              height: Style.space(64)
              radius: height / 2
              x: Model.polarX(ring.cx, ring.graphRadius, Model.sectorMidDeg(index)) - width / 2
              y: Model.polarY(ring.cy, ring.graphRadius, Model.sectorMidDeg(index)) - height / 2
              color: active ? root.activeColor : index === ring.hoverIndex ? Util.alpha(root.foreground, 0.12) : Color.popups.background
              border.width: selectedRoot || active ? 3 : 1
              border.color: active || selectedRoot ? root.activeColor : root.gridColor

              Column {
                anchors.centerIn: parent
                spacing: 0

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: note.shortLabel
                  color: active ? Color.popups.background : root.foreground
                  opacity: active ? 1 : 0.78
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.primaryKeyLabels[note.pitch]
                  color: active ? Color.popups.background : root.foreground
                  opacity: active ? 0.78 : 0.42
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: ring.hoverIndex = index
                onExited: if (ring.hoverIndex === index) ring.hoverIndex = -1
                onClicked: {
                  root.selectRoot(index)
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            width: ring.graphRadius * 1.05
            spacing: Style.space(5)

            Text {
              width: parent.width
              text: root.displayLabel
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.displayNoteNames
              color: root.foreground
              opacity: 0.72
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.keyboardMode ? (root.heldPitches.length > 0 ? "Nodes follow the keys currently held" : "Press any piano key") : "Click a note or play the keyboard"
              color: root.foreground
              opacity: 0.68
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

          }
        }

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "QUALITY"
            color: root.foreground
            opacity: 0.55
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            spacing: Style.space(5)
            Repeater {
              model: Model.QUALITIES
              delegate: Button {
                required property var modelData
                required property int index
                text: modelData.label
                selected: index === root.qualityIndex
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.bodySmall
                onClicked: {
                  root.selectQuality(index)
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(6)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "INVERSION"
            color: root.foreground
            opacity: 0.55
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Row {
            spacing: Style.space(5)
            Repeater {
              model: Model.INVERSIONS
              delegate: Button {
                required property var modelData
                required property int index
                text: modelData.label
                selected: index === root.inversionIndex
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.bodySmall
                onClicked: {
                  root.selectInversion(index)
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Button {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Play " + root.selectedChord.label
          selected: playFlash.running
          bordered: true
          foreground: root.foreground
          fontFamily: Style.font.family
          fontSize: Style.font.body
          tooltipText: "Milestone 1 records the atomic engine command without producing sound"
          onClicked: {
            root.playMock()
            keyCatcher.forceActiveFocus()
          }
        }

        Text {
          width: parent.width
          text: root.mockStatus
          color: root.foreground
          opacity: playFlash.running ? 0.9 : 0.5
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          text: "Piano keys: A S D F G H J K L ; ' Z X C V  ·  black: W E T Y U O P [ ] \\"
          color: root.foreground
          opacity: 0.45
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          text: "Each piano key is one fixed note · Esc close"
          color: root.foreground
          opacity: 0.45
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
  }
}
