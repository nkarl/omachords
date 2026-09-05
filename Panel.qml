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
  property int baseOctave: Model.DEFAULT_BASE_OCTAVE
  property bool settingsOpen: false
  property string audioStatus: "Choose an inversion to audition"

  readonly property color foreground: Color.foreground
  readonly property int baseMidi: Model.midiForC(root.baseOctave)
  readonly property string rangeLabel: Model.octaveRangeLabel(root.baseOctave)

  readonly property var pianoKeys: [
    Qt.Key_A, Qt.Key_W, Qt.Key_S, Qt.Key_E, Qt.Key_D, Qt.Key_F, Qt.Key_T, Qt.Key_G, Qt.Key_Y, Qt.Key_H, Qt.Key_U, Qt.Key_J,
    Qt.Key_K, Qt.Key_O, Qt.Key_L, Qt.Key_P, Qt.Key_Semicolon, Qt.Key_Apostrophe, Qt.Key_BracketLeft, Qt.Key_Z,
    Qt.Key_BracketRight, Qt.Key_X, Qt.Key_Backslash, Qt.Key_C, Qt.Key_V
  ]
  readonly property var pianoNotes: {
    var notes = []
    for (var index = 0; index < root.pianoKeys.length; index++) {
      var midi = root.baseMidi + index
      notes.push({ note: Model.midiNoteName(midi), midi: midi, key: root.pianoKeys[index] })
    }
    return notes
  }
  readonly property var selectedChord: Model.chord(root.rootIndex, root.qualityIndex, root.inversionIndex)
  readonly property var heldTriad: Model.identifyTriad(root.heldPitches, root.heldBass)
  readonly property string heldSummary: root.heldPitches.length === 0 ? "Press any piano key" : root.heldTriad ? "Held: " + root.heldTriad.label : "Held: " + Model.pitchSetNames(root.heldPitches)
  readonly property color gridColor: Util.alpha(root.foreground, 0.30)
  readonly property color quietColor: Util.alpha(root.foreground, 0.16)
  readonly property color activeColor: Color.accent
  readonly property color shadeColor: Util.alpha(root.foreground, 0.07)
  readonly property color shadeBorderColor: Util.alpha(root.foreground, 0.14)
  readonly property color chromaticActiveColor: Util.alpha(root.activeColor, 0.42)
  readonly property color chromaticHeldColor: Util.alpha(root.foreground, 0.20)
  readonly property color chromaticHeldBorderColor: Util.alpha(root.foreground, 0.68)
  readonly property color chromaticRootBorderColor: Util.alpha(root.foreground, 0.92)
  readonly property color transparentForeground: Util.alpha(root.foreground, 0.0)
  readonly property color transparentAccent: Util.alpha(root.activeColor, 0.0)
  readonly property var primaryKeyLabels: ["A", "W", "S", "E", "D", "F", "T", "G", "Y", "H", "U", "J"]

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.settingsOpen = false
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

  function configuredBaseOctave() {
    var config = root.shell ? root.shell.shellConfig : null
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    var pluginId = (root.manifest && root.manifest.id) || "local.chord-circle"
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (entry && entry.id === pluginId && entry.keyboardBaseOctave !== undefined)
        return Model.clampBaseOctave(entry.keyboardBaseOctave)
    }
    return Model.DEFAULT_BASE_OCTAVE
  }

  function loadSettings() {
    var octave = root.configuredBaseOctave()
    if (octave === root.baseOctave)
      return
    root.silenceForRangeChange()
    root.baseOctave = octave
  }

  function persistBaseOctave() {
    if (!root.shell || typeof root.shell.updateEntryInline !== "function")
      return
    var config = root.shell.shellConfig
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    var pluginId = (root.manifest && root.manifest.id) || "local.chord-circle"
    var settings = {}
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (!entry || entry.id !== pluginId)
        continue
      for (var key in entry)
        if (key !== "id")
          settings[key] = entry[key]
      break
    }
    settings.keyboardBaseOctave = root.baseOctave
    root.shell.updateEntryInline(pluginId, settings)
  }

  function setBaseOctave(octave) {
    var next = Model.clampBaseOctave(octave)
    if (next !== root.baseOctave) {
      root.silenceForRangeChange()
      root.baseOctave = next
      root.audioStatus = "Range set to " + root.rangeLabel
    }
    root.persistBaseOctave()
  }

  function openSettings() {
    root.silenceForRangeChange()
    root.settingsOpen = true
  }

  function closeSettings() {
    root.settingsOpen = false
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function silenceForRangeChange() {
    root.releaseAllKeys()
    root.revision += 1
    engine.stop(root.revision)
    playFlash.stop()
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
    engine.audition(root.revision, Model.midiVoicing(root.rootIndex, root.qualityIndex, index, root.baseMidi), 900)
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
  onShellChanged: root.loadSettings()

  Connections {
    target: root.shell
    function onShellConfigChanged() { root.loadSettings() }
  }

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
      width: Math.min(window.screen.width * 0.88, Style.space(1080))
      height: Math.min(window.screen.height * 0.92, Style.space(1180))
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
        if (root.settingsOpen) {
          if (event.key === Qt.Key_Escape)
            root.closeSettings()
          event.accepted = true
          return
        }
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
        if (root.settingsOpen) {
          event.accepted = true
          return
        }
        if (root.pianoNoteForKey(event.key)) {
          root.updatePianoKey(event.key, false, event.isAutoRepeat)
          event.accepted = true
        }
      }

      Button {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.space(28)
        z: 20
        text: "RANGE  " + root.rangeLabel
        tooltipText: "Change keyboard and audition range"
        bordered: true
        foreground: root.foreground
        fontFamily: Style.font.family
        fontSize: Style.font.caption
        onClicked: root.openSettings()
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
          height: Math.min(width, card.height - Style.space(250))
          property int hoverIndex: -1
          readonly property real cx: width / 2
          readonly property real cy: height / 2
          readonly property real outerRadius: Math.min(width, height) / 2 - Style.space(4)
          readonly property real beamLength: Math.min(Style.space(126), outerRadius * 0.29)
          readonly property real outerInnerRadius: outerRadius - beamLength
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

            function traceChromaticBlock(ctx, index) {
              var beamDegrees = 11.5
              var start = Model.degToRad(Model.chromaticMidDeg(index) - beamDegrees / 2)
              var end = Model.degToRad(Model.chromaticMidDeg(index) + beamDegrees / 2)
              ctx.beginPath()
              ctx.arc(ring.cx, ring.cy, ring.outerRadius, start, end, false)
              ctx.arc(ring.cx, ring.cy, ring.outerInnerRadius, end, start, true)
              ctx.closePath()
            }

            function radialFade(ctx, innerColor, outerColor) {
              var gradient = ctx.createRadialGradient(ring.cx, ring.cy, ring.outerInnerRadius, ring.cx, ring.cy, ring.outerRadius)
              gradient.addColorStop(0, innerColor)
              gradient.addColorStop(1, outerColor)
              return gradient
            }

            function drawChromaticBlock(ctx, index, fillColor, borderColor, borderWidth) {
              traceChromaticBlock(ctx, index)
              ctx.fillStyle = fillColor
              ctx.fill()
              ctx.strokeStyle = borderColor
              ctx.lineWidth = borderWidth
              ctx.stroke()
            }

            function outlineChromaticBlock(ctx, index, color, width) {
              traceChromaticBlock(ctx, index)
              ctx.strokeStyle = color
              ctx.lineWidth = width
              ctx.stroke()
            }

            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var quietFill = radialFade(ctx, root.shadeColor, root.transparentForeground)
              var quietBorder = radialFade(ctx, root.shadeBorderColor, root.transparentForeground)
              var presetFill = radialFade(ctx, root.chromaticActiveColor, root.transparentAccent)
              var heldFill = radialFade(ctx, root.chromaticHeldColor, root.transparentForeground)
              var heldBorder = radialFade(ctx, root.chromaticHeldBorderColor, root.transparentForeground)
              var rootBorder = radialFade(ctx, root.chromaticRootBorderColor, root.transparentForeground)
              for (var pitch = 0; pitch < Model.CHROMATIC.length; pitch++) {
                var preset = root.presetActive(pitch)
                var held = root.heldActive(pitch)
                drawChromaticBlock(ctx, pitch, preset ? presetFill : quietFill, quietBorder, 1)
                if (held)
                  drawChromaticBlock(ctx, pitch, heldFill, heldBorder, 2)
                if (pitch === root.selectedChord.rootPitch)
                  outlineChromaticBlock(ctx, pitch, rootBorder, 5)
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
              readonly property bool preset: root.presetActive(note.pitch)
              readonly property bool held: root.heldActive(note.pitch)
              readonly property bool selectedRoot: note.pitch === root.selectedChord.rootPitch
              readonly property real labelRadius: ring.outerInnerRadius + Style.space(24)
              width: Style.space(40)
              height: Style.space(24)
              x: Model.polarX(ring.cx, labelRadius, Model.chromaticMidDeg(note.pitch)) - width / 2
              y: Model.polarY(ring.cy, labelRadius, Model.chromaticMidDeg(note.pitch)) - height / 2

              Text {
                anchors.centerIn: parent
                text: note.label
                color: root.foreground
                opacity: parent.held ? 0.90 : parent.selectedRoot ? 0.80 : parent.preset ? 0.68 : 0.32
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: parent.preset || parent.held
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
                border.width: selectedRoot ? 5 : preset || held ? 2 : 1
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

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(parent.width, Style.space(900))
          spacing: Style.space(36)

          Column {
            width: (parent.width - parent.spacing) / 2
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
              anchors.horizontalCenter: parent.horizontalCenter
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
            width: (parent.width - parent.spacing) / 2
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
              anchors.horizontalCenter: parent.horizontalCenter
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
          text: "Range " + root.rangeLabel + " · Each piano key is one fixed note · Esc close"
          color: root.foreground
          opacity: 0.45
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.settingsOpen
        z: 100
        color: "#99000000"

        MouseArea {
          anchors.fill: parent
          onClicked: root.closeSettings()
        }

        Rectangle {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(64), Style.space(680))
          height: Style.space(310)
          radius: Math.max(Style.cornerRadius, Style.space(12))
          color: Color.popups.background
          border.color: Color.accent
          border.width: 2

          MouseArea {
            anchors.fill: parent
            onClicked: function(mouse) { mouse.accepted = true }
          }

          Column {
            anchors.fill: parent
            anchors.margins: Style.space(30)
            spacing: Style.space(16)

            Text {
              width: parent.width
              text: "TWO-OCTAVE RANGE"
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: "Set the register for both computer-key performance and inversion auditions."
              color: root.foreground
              opacity: 0.68
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.rangeLabel
              color: root.activeColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(5)

              Repeater {
                model: Model.MAX_BASE_OCTAVE - Model.MIN_BASE_OCTAVE + 1
                delegate: Button {
                  required property int index
                  readonly property int octave: Model.MIN_BASE_OCTAVE + index
                  text: Model.octaveRangeLabel(octave)
                  selected: octave === root.baseOctave
                  bordered: true
                  foreground: root.foreground
                  fontFamily: Style.font.family
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(9)
                  onClicked: root.setBaseOctave(octave)
                }
              }
            }

            Button {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Done"
              bordered: true
              foreground: root.foreground
              fontFamily: Style.font.family
              fontSize: Style.font.bodySmall
              onClicked: root.closeSettings()
            }
          }
        }
      }
    }
  }
  }
}
