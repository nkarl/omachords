import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property int rootIndex: 0
  property string chordFamily: "triad"
  property int qualityIndex: 0
  property int inversionIndex: 0
  property int revision: 0
  property var heldKeys: ({})
  property var heldPitches: []
  property int heldBass: -1
  property int rangeLowMidi: Model.DEFAULT_RANGE_LOW
  property int rangeHighMidi: Model.DEFAULT_RANGE_HIGH
  property var pianoKeys: defaultPianoKeys.slice(0)
  property bool onDemandFocus: false
  property bool settingsOpen: false
  property int bindingCaptureIndex: -1
  property string audioStatus: "Choose an inversion to audition"

  readonly property color foreground: Color.foreground
  readonly property var selectedRange: Model.normalizeMidiRange(root.rangeLowMidi, root.rangeHighMidi, "")
  readonly property string rangeLabel: selectedRange.label
  readonly property int mappedKeyCount: selectedRange.count
  readonly property var activeQualities: Model.qualitiesFor(root.chordFamily)
  readonly property var availableInversions: Model.INVERSIONS.slice(0, root.chordFamily === "seventh" ? 4 : 3)

  readonly property var defaultPianoKeys: [
    { key: Qt.Key_A, label: "A" }, { key: Qt.Key_W, label: "W" }, { key: Qt.Key_S, label: "S" },
    { key: Qt.Key_E, label: "E" }, { key: Qt.Key_D, label: "D" }, { key: Qt.Key_F, label: "F" },
    { key: Qt.Key_T, label: "T" }, { key: Qt.Key_G, label: "G" }, { key: Qt.Key_Y, label: "Y" },
    { key: Qt.Key_H, label: "H" }, { key: Qt.Key_U, label: "U" }, { key: Qt.Key_J, label: "J" },
    { key: Qt.Key_K, label: "K" }, { key: Qt.Key_O, label: "O" }, { key: Qt.Key_L, label: "L" },
    { key: Qt.Key_P, label: "P" }, { key: Qt.Key_Semicolon, label: ";" }, { key: Qt.Key_Apostrophe, label: "'" },
    { key: Qt.Key_BracketLeft, label: "[" }, { key: Qt.Key_Z, label: "Z" }, { key: Qt.Key_BracketRight, label: "]" },
    { key: Qt.Key_X, label: "X" }, { key: Qt.Key_Backslash, label: "\\" }, { key: Qt.Key_C, label: "C" },
    { key: Qt.Key_V, label: "V" }, { key: Qt.Key_B, label: "B" }, { key: Qt.Key_N, label: "N" },
    { key: Qt.Key_M, label: "M" }, { key: Qt.Key_Comma, label: "," }, { key: Qt.Key_Period, label: "." },
    { key: Qt.Key_Slash, label: "/" }
  ]
  readonly property var pianoNotes: {
    var notes = []
    var count = Math.min(root.mappedKeyCount, root.pianoKeys.length)
    for (var index = 0; index < count; index++) {
      var midi = root.rangeLowMidi + index
      notes.push({ note: Model.midiNoteName(midi), midi: midi, key: root.pianoKeys[index].key, keyLabel: root.pianoKeys[index].label })
    }
    return notes
  }
  readonly property var selectedChord: root.qualityIndex >= 0 ? Model.chord(root.rootIndex, root.qualityIndex, root.inversionIndex, root.chordFamily) : {
    rootPitch: Model.noteAt(root.rootIndex).pitch,
    pitches: [],
    label: Model.noteAt(root.rootIndex).label,
    noteNames: "Choose a quality",
    degreeNames: "",
    semitoneNames: ""
  }
  readonly property var heldChord: Model.identifyChord(root.heldPitches, root.heldBass)
  readonly property string heldSummary: root.heldPitches.length === 0 ? "Press any piano key" : root.heldChord ? "Held: " + root.heldChord.label : "Held: " + Model.pitchSetNames(root.heldPitches)
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

  function open(payloadJson) {
    root.onDemandFocus = false
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.settingsOpen = false
    root.releaseAllKeys()
    root.revision += 1
    engine.stop(root.revision)
    root.opened = false
    root.onDemandFocus = false
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

  function configuredMidiRange() {
    var config = root.shell ? root.shell.shellConfig : null
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    var pluginId = (root.manifest && root.manifest.id) || "local.chord-circle"
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (!entry || entry.id !== pluginId)
        continue
      if (entry.rangeLowMidi !== undefined && entry.rangeHighMidi !== undefined)
        return Model.normalizeMidiRange(entry.rangeLowMidi, entry.rangeHighMidi, "")
      if (entry.keyboardBaseOctave !== undefined) {
        var oldLow = Model.midiForC(entry.keyboardBaseOctave)
        var oldHigh = oldLow + 24
        if (oldLow < Model.MIN_RANGE_MIDI) {
          oldHigh += Model.MIN_RANGE_MIDI - oldLow
          oldLow = Model.MIN_RANGE_MIDI
        }
        if (oldHigh > Model.MAX_RANGE_MIDI) {
          oldLow -= oldHigh - Model.MAX_RANGE_MIDI
          oldHigh = Model.MAX_RANGE_MIDI
        }
        return Model.normalizeMidiRange(oldLow, oldHigh, "")
      }
    }
    return Model.normalizeMidiRange(Model.DEFAULT_RANGE_LOW, Model.DEFAULT_RANGE_HIGH, "")
  }

  function normalizedKeyBindings(value) {
    return Model.normalizeKeyBindings(value, root.defaultPianoKeys)
  }

  function configuredKeyBindings() {
    var config = root.shell ? root.shell.shellConfig : null
    var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    var pluginId = (root.manifest && root.manifest.id) || "local.chord-circle"
    for (var i = 0; i < plugins.length; i++) {
      var entry = plugins[i]
      if (entry && entry.id === pluginId && entry.keyBindings !== undefined)
        return root.normalizedKeyBindings(entry.keyBindings)
    }
    return root.defaultPianoKeys.slice(0)
  }

  function sameKeyBindings(first, second) {
    return Model.sameKeyBindings(first, second)
  }

  function loadSettings() {
    var range = root.configuredMidiRange()
    var bindings = root.configuredKeyBindings()
    if (range.low === root.rangeLowMidi && range.high === root.rangeHighMidi && root.sameKeyBindings(bindings, root.pianoKeys))
      return
    root.silenceForRangeChange()
    root.rangeLowMidi = range.low
    root.rangeHighMidi = range.high
    root.pianoKeys = bindings
  }

  function persistSettings() {
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
        if (key !== "id" && key !== "keyboardBaseOctave" && key !== "onDemandFocus")
          settings[key] = entry[key]
      break
    }
    settings.rangeLowMidi = root.rangeLowMidi
    settings.rangeHighMidi = root.rangeHighMidi
    settings.keyBindings = root.pianoKeys
    root.shell.updateEntryInline(pluginId, settings)
  }

  function setOnDemandFocus(enabled) {
    var next = enabled === true
    if (next === root.onDemandFocus)
      return
    root.silenceForRangeChange()
    root.onDemandFocus = next
    root.audioStatus = next ? "On-demand focus enabled" : "Exclusive focus enabled"
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function keyLabelForEvent(event) {
    if (event.key === Qt.Key_Space)
      return "Space"
    var label = event.text || ""
    if (label.length === 1)
      return label.toUpperCase()
    return "Key " + event.key
  }

  function isBindableKey(key) {
    return key !== Qt.Key_unknown && key !== Qt.Key_Escape && key !== Qt.Key_Shift && key !== Qt.Key_Control && key !== Qt.Key_Alt && key !== Qt.Key_Meta && key !== Qt.Key_AltGr
  }

  function captureBinding(event) {
    if (root.bindingCaptureIndex < 0 || event.isAutoRepeat)
      return
    if (event.key === Qt.Key_Escape) {
      root.bindingCaptureIndex = -1
      return
    }
    if (!root.isBindableKey(event.key)) {
      root.audioStatus = "Choose a non-modifier key"
      return
    }
    var replacement = { key: event.key, label: root.keyLabelForEvent(event) }
    root.pianoKeys = Model.rebindKey(root.pianoKeys, root.bindingCaptureIndex, replacement)
    root.bindingCaptureIndex = -1
    root.audioStatus = "Keyboard binding updated"
    root.persistSettings()
  }

  function resetKeyBindings() {
    root.pianoKeys = root.defaultPianoKeys.slice(0)
    root.bindingCaptureIndex = -1
    root.audioStatus = "Keyboard bindings reset"
    root.persistSettings()
  }

  function keyMapSummary() {
    var labels = []
    for (var i = 0; i < root.mappedKeyCount; i++)
      labels.push(root.pianoKeys[i].label)
    return labels.join(" ")
  }

  function applyMidiRange(range) {
    if (range.low === root.rangeLowMidi && range.high === root.rangeHighMidi)
      return false
    root.rangeLowMidi = range.low
    root.rangeHighMidi = range.high
    root.audioStatus = "Range set to " + root.rangeLabel
    return true
  }

  function setRangeLower(midi) {
    root.applyMidiRange(Model.normalizeMidiRange(midi, root.rangeHighMidi, "lower"))
  }

  function setRangeUpper(midi) {
    root.applyMidiRange(Model.normalizeMidiRange(root.rangeLowMidi, midi, "upper"))
  }

  function openSettings() {
    root.silenceForRangeChange()
    root.settingsOpen = true
  }

  function closeSettings() {
    root.bindingCaptureIndex = -1
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
    var normalizedQuality = nextQuality < 0 ? -1 : Model.wrap(nextQuality, root.activeQualities.length)
    var normalizedInversion = normalizedQuality < 0 ? 0 : Model.wrap(nextInversion, root.availableInversions.length)
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

  function setChordFamily(family) {
    var normalized = family === "seventh" ? "seventh" : "triad"
    if (normalized === root.chordFamily)
      return
    root.releaseAllKeys()
    root.chordFamily = normalized
    root.qualityIndex = 0
    root.inversionIndex = 0
    root.revision += 1
    engine.stop(root.revision)
    playFlash.stop()
    root.audioStatus = normalized === "seventh" ? "Seventh chords selected" : "Triads selected"
    graph.requestPaint()
  }

  function selectQuality(index) {
    var nextQuality = Model.toggleExclusiveIndex(root.qualityIndex, index)
    if (!root.setSelection(root.rootIndex, nextQuality, root.inversionIndex))
      return
    if (nextQuality < 0) {
      engine.stop(root.revision)
      playFlash.stop()
      root.audioStatus = "Choose a quality"
    }
  }

  function auditionInversion(index) {
    if (root.qualityIndex < 0) {
      root.audioStatus = "Choose a quality before auditioning"
      return
    }
    var changed = root.setSelection(root.rootIndex, root.qualityIndex, index)
    if (!changed)
      root.revision += 1
    var chord = Model.chord(root.rootIndex, root.qualityIndex, index, root.chordFamily)
    var notes = Model.midiVoicingInRange(root.rootIndex, root.qualityIndex, index, root.rangeLowMidi, root.rangeHighMidi, root.chordFamily)
    engine.audition(root.revision, notes, notes.length > 0 ? 900 : 50)
    if (notes.length === 0) {
      root.audioStatus = chord.label + " · " + chord.inversionLabel + " inversion does not fit " + root.rangeLabel
      playFlash.stop()
      return
    }
    root.audioStatus = "Auditioning " + chord.label + " · " + chord.inversionLabel + " inversion"
    playFlash.restart()
  }

  function pianoNoteForKey(key) {
    for (var i = 0; i < root.pianoNotes.length; i++)
      if (root.pianoNotes[i].key === key)
        return root.pianoNotes[i]
    return null
  }

  function keyLabelForPitch(pitch) {
    for (var i = 0; i < root.pianoNotes.length; i++)
      if (Model.wrap(root.pianoNotes[i].midi, 12) === pitch)
        return root.pianoNotes[i].keyLabel
    return ""
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
      var identified = Model.identifyChord(state.pitches, root.heldBass)
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

  function roleForPitch(pitch) {
    if (root.heldActive(pitch) && root.heldChord)
      return Model.chordRole(root.heldChord, pitch)
    if (root.presetActive(pitch))
      return Model.chordRole(root.selectedChord, pitch)
    return ""
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
    WlrLayershell.keyboardFocus: root.onDemandFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive

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
        onActiveFocusChanged: if (!activeFocus && root.onDemandFocus) root.releaseAllKeys()
        Keys.priority: Keys.BeforeItem

      Keys.onPressed: function(event) {
        if (root.settingsOpen) {
          if (root.bindingCaptureIndex >= 0)
            root.captureBinding(event)
          else if (event.key === Qt.Key_Escape)
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

      Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: Style.space(28)
        z: 20
        spacing: Style.space(8)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.rangeLabel + " · " + root.mappedKeyCount + " keys"
          color: root.foreground
          opacity: 0.55
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }

        PanelActionButton {
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰒓"
          tooltipText: "Settings"
          foreground: root.foreground
          fontFamily: Style.font.family
          fontSize: Style.font.icon
          size: Style.space(30)
          focusable: true
          bordered: true
          onClicked: root.openSettings()
        }
      }

      Column {
        id: content
        anchors.fill: parent
        anchors.margins: Style.space(28)
        spacing: Style.space(14)

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
                    text: preset || held ? (root.roleForPitch(note.pitch) || root.keyLabelForPitch(note.pitch)) : root.keyLabelForPitch(note.pitch)
                    color: preset || held ? Color.popups.background : root.foreground
                    opacity: preset || held ? 0.92 : 0.42
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: preset || held
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

          Repeater {
            model: Model.CHROMATIC.length
            delegate: Rectangle {
              required property int index
              readonly property var note: Model.chromaticNoteAt(index)
              readonly property real markerRadius: ring.graphRadius * 0.70
              visible: root.heldActive(note.pitch)
              width: Style.space(38)
              height: Style.space(24)
              radius: height / 2
              x: Model.polarX(ring.cx, markerRadius, Model.chromaticMidDeg(note.pitch)) - width / 2
              y: Model.polarY(ring.cy, markerRadius, Model.chromaticMidDeg(note.pitch)) - height / 2
              color: Util.alpha(root.foreground, 0.12)
              border.width: 1
              border.color: Util.alpha(root.foreground, 0.48)

              Text {
                anchors.centerIn: parent
                text: parent.note.pitch
                color: root.foreground
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          Column {
            anchors.centerIn: parent
            width: ring.graphRadius * 1.05
            spacing: Style.space(5)

            Text {
              width: parent.width
              height: Style.space(24)
              text: root.selectedChord.label
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            Text {
              width: parent.width
              height: Style.space(22)
              text: root.selectedChord.noteNames
              color: root.foreground
              opacity: 0.72
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            Text {
              width: parent.width
              height: Style.space(22)
              text: root.selectedChord.degreeNames
              visible: root.qualityIndex >= 0
              color: root.activeColor
              opacity: 0.92
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }

            Text {
              width: parent.width
              height: Style.space(22)
              text: root.selectedChord.semitoneNames
              visible: root.qualityIndex >= 0
              color: root.foreground
              opacity: 0.58
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
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

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(5)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "QUALITY"
                color: root.foreground
                opacity: 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Button {
                text: "TRIAD"
                selected: root.chordFamily === "triad"
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.caption
                horizontalPadding: Style.space(7)
                verticalPadding: Style.space(3)
                onClicked: root.setChordFamily("triad")
              }

              Button {
                text: "7TH"
                selected: root.chordFamily === "seventh"
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.caption
                horizontalPadding: Style.space(7)
                verticalPadding: Style.space(3)
                onClicked: root.setChordFamily("seventh")
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(5)
              Repeater {
                model: root.activeQualities
                delegate: Button {
                  required property var modelData
                  required property int index
                  text: modelData.shortLabel
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
                model: root.availableInversions
                delegate: Button {
                  required property var modelData
                  required property int index
                  text: modelData.label + "  ▶"
                  selected: playFlash.running && index === root.inversionIndex
                  enabled: root.qualityIndex >= 0
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
          text: "Keys low → high: " + root.keyMapSummary()
          color: root.foreground
          opacity: 0.45
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          text: "Range " + root.rangeLabel + " · " + root.mappedKeyCount + " fixed-note keys · Esc close"
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
          height: Style.space(720)
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
              text: "SETTINGS"
              color: root.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Row {
              width: parent.width
              spacing: Style.space(16)

              Column {
                width: parent.width - focusToggle.width - parent.spacing
                spacing: Style.space(3)

                Text {
                  width: parent.width
                  text: "ON-DEMAND FOCUS"
                  color: root.foreground
                  opacity: 0.72
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  width: parent.width
                  text: "Allow other windows to receive focus while Chord Circle remains open."
                  color: root.foreground
                  opacity: 0.55
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }
              }

              ToggleSwitch {
                id: focusToggle
                anchors.verticalCenter: parent.verticalCenter
                checked: root.onDemandFocus
                foreground: root.foreground
                accent: root.activeColor
                onToggled: root.setOnDemandFocus(!root.onDemandFocus)
              }
            }

            Text {
              width: parent.width
              text: "VOCAL RANGE"
              color: root.foreground
              opacity: 0.6
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: "Choose any span from C2 to C6, up to 31 keys (2.5 octaves)."
              color: root.foreground
              opacity: 0.68
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
              horizontalAlignment: Text.AlignHCenter
            }

            Text {
              width: parent.width
              text: root.rangeLabel + "  ·  " + root.mappedKeyCount + " keys"
              color: root.activeColor
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
            }

            QQC.RangeSlider {
              id: rangeSlider
              anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - Style.space(48)
              from: Model.MIN_RANGE_MIDI
              to: Model.MAX_RANGE_MIDI
              stepSize: 1
              snapMode: QQC.RangeSlider.SnapAlways
              first.value: root.rangeLowMidi
              second.value: root.rangeHighMidi
              first.onMoved: root.setRangeLower(Math.round(first.value))
              second.onMoved: root.setRangeUpper(Math.round(second.value))
              first.onPressedChanged: if (!first.pressed) root.persistSettings()
              second.onPressedChanged: if (!second.pressed) root.persistSettings()

              background: Rectangle {
                x: rangeSlider.leftPadding
                y: rangeSlider.topPadding + rangeSlider.availableHeight / 2 - height / 2
                width: rangeSlider.availableWidth
                height: Style.space(5)
                radius: height / 2
                color: root.quietColor

                Rectangle {
                  x: rangeSlider.first.visualPosition * parent.width
                  width: (rangeSlider.second.visualPosition - rangeSlider.first.visualPosition) * parent.width
                  height: parent.height
                  radius: parent.radius
                  color: root.activeColor
                }
              }

              first.handle: Rectangle {
                x: rangeSlider.leftPadding + rangeSlider.first.visualPosition * (rangeSlider.availableWidth - width)
                y: rangeSlider.topPadding + rangeSlider.availableHeight / 2 - height / 2
                implicitWidth: Style.space(24)
                implicitHeight: implicitWidth
                radius: width / 2
                color: root.foreground
                border.width: 3
                border.color: root.activeColor
              }

              second.handle: Rectangle {
                x: rangeSlider.leftPadding + rangeSlider.second.visualPosition * (rangeSlider.availableWidth - width)
                y: rangeSlider.topPadding + rangeSlider.availableHeight / 2 - height / 2
                implicitWidth: Style.space(24)
                implicitHeight: implicitWidth
                radius: width / 2
                color: root.foreground
                border.width: 3
                border.color: root.activeColor
              }
            }

            Row {
              width: rangeSlider.width
              anchors.horizontalCenter: parent.horizontalCenter

              Text {
                width: parent.width / 2
                text: "C2"
                color: root.foreground
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                width: parent.width / 2
                text: "C6"
                color: root.foreground
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }
            }

            Row {
              width: parent.width

              Text {
                width: parent.width - resetBindings.width
                text: root.bindingCaptureIndex >= 0 ? "Press a replacement key · duplicates swap positions" : "KEYBOARD MAP · select a slot to rebind"
                color: root.foreground
                opacity: root.bindingCaptureIndex >= 0 ? 0.9 : 0.6
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
                verticalAlignment: Text.AlignVCenter
              }

              Button {
                id: resetBindings
                text: "Reset"
                bordered: true
                foreground: root.foreground
                fontFamily: Style.font.family
                fontSize: Style.font.caption
                onClicked: root.resetKeyBindings()
              }
            }

            Grid {
              anchors.horizontalCenter: parent.horizontalCenter
              columns: 8
              spacing: Style.space(5)

              Repeater {
                model: root.pianoKeys.length
                delegate: Button {
                  required property int index
                  readonly property bool activeSlot: index < root.mappedKeyCount
                  text: (index + 1) + " · " + (root.bindingCaptureIndex === index ? "…" : root.pianoKeys[index].label)
                  selected: root.bindingCaptureIndex === index
                  bordered: true
                  foreground: root.foreground
                  opacity: activeSlot ? 1 : 0.42
                  fontFamily: Style.font.family
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(8)
                  onClicked: root.bindingCaptureIndex = index
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
