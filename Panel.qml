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
  property string audioStatus: "Choose an inversion to audition"

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
  readonly property var heldTriad: Model.identifyTriad(root.heldPitches, root.heldBass)
  readonly property string heldSummary: root.heldPitches.length === 0 ? "Press any piano key" : root.heldTriad ? "Held: " + root.heldTriad.label : "Held: " + Model.pitchSetNames(root.heldPitches)
  readonly property color gridColor: Util.alpha(root.foreground, 0.30)
  readonly property color quietColor: Util.alpha(root.foreground, 0.16)
  readonly property color activeColor: Color.accent
  readonly property color shadeColor: Util.alpha(root.foreground, 0.07)
  readonly property color shadeBorderColor: Util.alpha(root.foreground, 0.14)
  readonly property color chromaticActiveColor: Util.alpha(root.activeColor, 0.34)
  readonly property var primaryKeyLabels: ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J"]

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.releaseAllKeys()
    root.revision += 1
    engine.stop(root.revision)
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
      return false

    root.rootIndex = normalizedRoot
    root.qualityIndex = normalizedQuality
    root.inversionIndex = normalizedInversion
    root.revision += 1
    graph.requestPaint()
    return true
  }

  function selectRoot(index) {
    root.setSelection(index, root.qualityIndex, root.inversionIndex)
  }

  function selectQuality(index) {
    root.setSelection(root.rootIndex, index, root.inversionIndex)
  }

  function auditionInversion(index) {
    var changed = root.setSelection(root.rootIndex, root.qualityIndex, index)
    if (!changed)
      root.revision += 1
    var chord = Model.chord(root.rootIndex, root.qualityIndex, index)
    engine.audition(root.revision, Model.midiVoicing(root.rootIndex, root.qualityIndex, index), 900)
    root.audioStatus = "Auditioning " + chord.label + " · " + chord.inversionLabel + " inversion"
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
      engine.setHeld(root.revision, state.midiNotes)
      var identified = Model.identifyTriad(state.pitches, root.heldBass)
      root.audioStatus = "Held " + (identified ? identified.label : Model.pitchSetNames(state.pitches))
    } else {
      engine.setHeld(root.revision, [])
      root.audioStatus = "All keys released"
    }
    graph.requestPaint()
    return state
  }

  function updatePianoKey(key, pressed, autoRepeat) {
    var note = root.pianoNoteForKey(key)
    var next = Model.updateHeldKeys(root.heldKeys, key, note, pressed, autoRepeat)
    if (next === root.heldKeys)
      return false
    root.rebuildHeldState(next)
    return true
  }

  function releaseAllKeys() {
    if (Object.keys(root.heldKeys).length === 0)
      return
    root.rebuildHeldState({})
  }

  function presetActive(pitch) {
    return Model.contains(root.selectedChord.pitches, pitch)
  }

  function heldActive(pitch) {
    return Model.contains(root.heldPitches, pitch)
  }

  onSelectedChordChanged: graph.requestPaint()
  onHeldPitchesChanged: graph.requestPaint()
  onOpenedChanged: if (!root.opened) root.releaseAllKeys()

  EngineAdapter {
    id: engine
  }

  Timer {
    id: playFlash
    interval: 1200
    onTriggered: root.audioStatus = "Choose an inversion to audition"
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
          readonly property real outerRadius: Math.min(width, height) / 2 - Style.space(4)
          readonly property real outerInnerRadius: outerRadius - Style.space(42)
          readonly property real graphRadius: outerInnerRadius - Style.space(54)

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

            function drawChromaticBlock(ctx, index, fillColor) {
              var gapDegrees = 1.15
              var start = Model.degToRad(Model.chromaticMidDeg(index) - Model.SECTOR_DEG / 2 + gapDegrees / 2)
              var end = Model.degToRad(Model.chromaticMidDeg(index) + Model.SECTOR_DEG / 2 - gapDegrees / 2)
              ctx.beginPath()
              ctx.arc(ring.cx, ring.cy, ring.outerRadius, start, end, false)
              ctx.arc(ring.cx, ring.cy, ring.outerInnerRadius, end, start, true)
              ctx.closePath()
              ctx.fillStyle = fillColor
              ctx.fill()
              ctx.strokeStyle = root.shadeBorderColor
              ctx.lineWidth = 1
              ctx.stroke()
            }

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              for (var pitch = 0; pitch < Model.CHROMATIC.length; pitch++) {
                var chromaticActive = root.presetActive(pitch) || root.heldActive(pitch)
                drawChromaticBlock(ctx, pitch, chromaticActive ? root.chromaticActiveColor : root.shadeColor)
              }
              ctx.strokeStyle = root.quietColor
              ctx.lineWidth = 1.5
              ctx.beginPath()
              ctx.arc(ring.cx, ring.cy, ring.graphRadius, 0, Math.PI * 2)
              ctx.stroke()
              drawEdges(ctx, Model.edges(root.selectedChord.pitches), root.activeColor, 3)
              drawEdges(ctx, Model.edges(root.heldPitches), root.foreground, 4)
            }
          }

          Repeater {
            model: Model.CHROMATIC.length
            delegate: Item {
              required property int index
              readonly property var note: Model.chromaticNoteAt(index)
              readonly property bool active: root.presetActive(note.pitch) || root.heldActive(note.pitch)
              readonly property real labelRadius: (ring.outerRadius + ring.outerInnerRadius) / 2
              width: Style.space(40)
              height: Style.space(24)
              x: Model.polarX(ring.cx, labelRadius, Model.chromaticMidDeg(note.pitch)) - width / 2
              y: Model.polarY(ring.cy, labelRadius, Model.chromaticMidDeg(note.pitch)) - height / 2

              Text {
                anchors.centerIn: parent
                text: note.label
                color: root.foreground
                opacity: parent.active ? 0.68 : 0.32
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: parent.active
              }
            }
          }

          Repeater {
            model: Model.FIFTHS.length
            delegate: Item {
              required property int index
              readonly property var note: Model.noteAt(index)
              readonly property bool selectedRoot: index === root.rootIndex
              readonly property bool preset: root.presetActive(note.pitch)
              readonly property bool held: root.heldActive(note.pitch)
              width: Style.space(76)
              height: Style.space(76)
              x: Model.polarX(ring.cx, ring.graphRadius, Model.sectorMidDeg(index)) - width / 2
              y: Model.polarY(ring.cy, ring.graphRadius, Model.sectorMidDeg(index)) - height / 2

              Rectangle {
                anchors.centerIn: parent
                width: Style.space(76)
                height: width
                radius: width / 2
                visible: held
                color: Util.alpha(root.foreground, 0.18)
                border.width: 3
                border.color: root.foreground
              }

              Rectangle {
                id: nodeCore
                anchors.centerIn: parent
                width: Style.space(62)
                height: width
                radius: width / 2
                color: preset ? root.activeColor : held ? root.foreground : index === ring.hoverIndex ? Util.alpha(root.foreground, 0.12) : Color.popups.background
                border.width: selectedRoot ? 3 : preset || held ? 2 : 1
                border.color: selectedRoot ? root.foreground : preset ? root.activeColor : held ? root.foreground : root.gridColor

                Column {
                  anchors.centerIn: parent
                  spacing: 0

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: note.shortLabel
                    color: preset || held ? Color.popups.background : root.foreground
                    opacity: preset || held ? 1 : 0.78
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.primaryKeyLabels[note.pitch]
                    color: preset || held ? Color.popups.background : root.foreground
                    opacity: preset || held ? 0.78 : 0.42
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }
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
              text: root.selectedChord.label
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.selectedChord.noteNames
              color: root.foreground
              opacity: 0.72
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.heldSummary
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
                text: modelData.label + "  ▶"
                selected: playFlash.running && index === root.inversionIndex
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.bodySmall
                onClicked: {
                  root.auditionInversion(index)
                  keyCatcher.forceActiveFocus()
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: root.audioStatus + " · " + engine.detail
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
