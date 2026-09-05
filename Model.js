.pragma library

var SECTORS = 12
var SECTOR_DEG = 360 / SECTORS
var TOP_DEG = -90
var MIN_RANGE_MIDI = 36
var MAX_RANGE_MIDI = 84
var MAX_RANGE_KEYS = 31
var DEFAULT_RANGE_LOW = 48
var DEFAULT_RANGE_HIGH = 72
var MIDI_SHARP_NAMES = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

// Clockwise from 12 o'clock, matching the circle of fifths.
var FIFTHS = [
  { pitch: 0, label: "C", shortLabel: "C" },
  { pitch: 7, label: "G", shortLabel: "G" },
  { pitch: 2, label: "D", shortLabel: "D" },
  { pitch: 9, label: "A", shortLabel: "A" },
  { pitch: 4, label: "E", shortLabel: "E" },
  { pitch: 11, label: "B", shortLabel: "B" },
  { pitch: 6, label: "F♯ / G♭", shortLabel: "F♯" },
  { pitch: 1, label: "D♭ / C♯", shortLabel: "D♭" },
  { pitch: 8, label: "A♭ / G♯", shortLabel: "A♭" },
  { pitch: 3, label: "E♭ / D♯", shortLabel: "E♭" },
  { pitch: 10, label: "B♭ / A♯", shortLabel: "B♭" },
  { pitch: 5, label: "F", shortLabel: "F" }
]

// Clockwise from 12 o'clock in strict semitone order.
var CHROMATIC = [
  { pitch: 0, label: "C" }, { pitch: 1, label: "D♭" },
  { pitch: 2, label: "D" }, { pitch: 3, label: "E♭" },
  { pitch: 4, label: "E" }, { pitch: 5, label: "F" },
  { pitch: 6, label: "G♭" }, { pitch: 7, label: "G" },
  { pitch: 8, label: "A♭" }, { pitch: 9, label: "A" },
  { pitch: 10, label: "B♭" }, { pitch: 11, label: "B" }
]

var QUALITIES = [
  { id: "major", label: "Major", shortLabel: "Major", symbol: "", intervals: [0, 4, 7], degrees: ["1", "3", "5"], triadQualityIndex: 0 },
  { id: "minor", label: "Minor", shortLabel: "Minor", symbol: "m", intervals: [0, 3, 7], degrees: ["1", "♭3", "5"], triadQualityIndex: 1 },
  { id: "diminished", label: "Diminished", shortLabel: "Dim", symbol: "dim", intervals: [0, 3, 6], degrees: ["1", "♭3", "♭5"], triadQualityIndex: 2 },
  { id: "augmented", label: "Augmented", shortLabel: "Aug", symbol: "aug", intervals: [0, 4, 8], degrees: ["1", "3", "♯5"], triadQualityIndex: 3 }
]

var SEVENTH_QUALITIES = [
  { id: "major7", label: "Major seventh", shortLabel: "maj7", symbol: "maj7", intervals: [0, 4, 7, 11], degrees: ["1", "3", "5", "7"], triadQualityIndex: 0 },
  { id: "dominant7", label: "Dominant seventh", shortLabel: "7", symbol: "7", intervals: [0, 4, 7, 10], degrees: ["1", "3", "5", "♭7"], triadQualityIndex: 0 },
  { id: "minor7", label: "Minor seventh", shortLabel: "m7", symbol: "m7", intervals: [0, 3, 7, 10], degrees: ["1", "♭3", "5", "♭7"], triadQualityIndex: 1 },
  { id: "halfDiminished7", label: "Half-diminished seventh", shortLabel: "m7♭5", symbol: "m7♭5", intervals: [0, 3, 6, 10], degrees: ["1", "♭3", "♭5", "♭7"], triadQualityIndex: 2 },
  { id: "diminished7", label: "Diminished seventh", shortLabel: "dim7", symbol: "dim7", intervals: [0, 3, 6, 9], degrees: ["1", "♭3", "♭5", "𝄫7"], triadQualityIndex: 2 },
  { id: "augmentedMajor7", label: "Augmented major seventh", shortLabel: "augMaj7", symbol: "augMaj7", intervals: [0, 4, 8, 11], degrees: ["1", "3", "♯5", "7"], triadQualityIndex: 3 },
  { id: "minorMajor7", label: "Minor-major seventh", shortLabel: "mMaj7", symbol: "mMaj7", intervals: [0, 3, 7, 11], degrees: ["1", "♭3", "5", "7"], triadQualityIndex: 1 }
]

var INVERSIONS = [
  { id: "root", label: "Root", shortLabel: "R" },
  { id: "first", label: "First", shortLabel: "1st" },
  { id: "second", label: "Second", shortLabel: "2nd" },
  { id: "third", label: "Third", shortLabel: "3rd" }
]

var FLAT_NAMES = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

// Spellings are indexed by quality, then by root sector in FIFTHS. Some
// enharmonic sectors choose a different root spelling to keep the triad
// readable (for example C♯ minor rather than D♭ minor).
var TRIAD_SPELLINGS = [
  [
    ["C", "E", "G"], ["G", "B", "D"], ["D", "F♯", "A"], ["A", "C♯", "E"],
    ["E", "G♯", "B"], ["B", "D♯", "F♯"], ["F♯", "A♯", "C♯"], ["D♭", "F", "A♭"],
    ["A♭", "C", "E♭"], ["E♭", "G", "B♭"], ["B♭", "D", "F"], ["F", "A", "C"]
  ],
  [
    ["C", "E♭", "G"], ["G", "B♭", "D"], ["D", "F", "A"], ["A", "C", "E"],
    ["E", "G", "B"], ["B", "D", "F♯"], ["F♯", "A", "C♯"], ["C♯", "E", "G♯"],
    ["A♭", "C♭", "E♭"], ["E♭", "G♭", "B♭"], ["B♭", "D♭", "F"], ["F", "A♭", "C"]
  ],
  [
    ["C", "E♭", "G♭"], ["G", "B♭", "D♭"], ["D", "F", "A♭"], ["A", "C", "E♭"],
    ["E", "G", "B♭"], ["B", "D", "F"], ["F♯", "A", "C"], ["C♯", "E", "G"],
    ["G♯", "B", "D"], ["D♯", "F♯", "A"], ["A♯", "C♯", "E"], ["F", "A♭", "C♭"]
  ],
  [
    ["C", "E", "G♯"], ["G", "B", "D♯"], ["D", "F♯", "A♯"], ["A", "C♯", "E♯"],
    ["E", "G♯", "B♯"], ["B", "D♯", "F𝄪"], ["G♭", "B♭", "D"], ["D♭", "F", "A"],
    ["A♭", "C", "E"], ["E♭", "G", "B"], ["B♭", "D", "F♯"], ["F", "A", "C♯"]
  ]
]

function wrap(value, length) {
  var n = length > 0 ? length : 1
  return ((Number(value) % n) + n) % n
}

function noteAt(index) {
  return FIFTHS[wrap(index, FIFTHS.length)]
}

function chromaticNoteAt(index) {
  return CHROMATIC[wrap(index, CHROMATIC.length)]
}

function qualitiesFor(family) {
  return family === "seventh" ? SEVENTH_QUALITIES : QUALITIES
}

function qualityAt(index, family) {
  var qualities = qualitiesFor(family)
  return qualities[wrap(index, qualities.length)]
}

function toggleExclusiveIndex(current, requested) {
  return Number(current) === Number(requested) ? -1 : Math.round(Number(requested))
}

function inversionAt(index) {
  return INVERSIONS[wrap(index, INVERSIONS.length)]
}

function pitchName(pitch) {
  return FLAT_NAMES[wrap(pitch, 12)]
}

function midiForC(octave) {
  return (Math.round(Number(octave)) + 1) * 12
}

function midiNoteName(midi) {
  var note = Math.max(0, Math.min(127, Math.round(Number(midi))))
  return MIDI_SHARP_NAMES[wrap(note, 12)] + (Math.floor(note / 12) - 1)
}

function normalizeMidiRange(low, high, movedBound) {
  var normalizedLow = Math.round(Number(low))
  var normalizedHigh = Math.round(Number(high))
  if (!isFinite(normalizedLow))
    normalizedLow = DEFAULT_RANGE_LOW
  if (!isFinite(normalizedHigh))
    normalizedHigh = DEFAULT_RANGE_HIGH
  normalizedLow = Math.max(MIN_RANGE_MIDI, Math.min(MAX_RANGE_MIDI, normalizedLow))
  normalizedHigh = Math.max(MIN_RANGE_MIDI, Math.min(MAX_RANGE_MIDI, normalizedHigh))
  if (normalizedLow > normalizedHigh) {
    if (movedBound === "lower")
      normalizedHigh = normalizedLow
    else
      normalizedLow = normalizedHigh
  }
  if (normalizedHigh - normalizedLow >= MAX_RANGE_KEYS) {
    if (movedBound === "lower")
      normalizedHigh = normalizedLow + MAX_RANGE_KEYS - 1
    else
      normalizedLow = normalizedHigh - MAX_RANGE_KEYS + 1
  }
  return {
    low: normalizedLow,
    high: normalizedHigh,
    count: normalizedHigh - normalizedLow + 1,
    label: midiNoteName(normalizedLow) + "–" + midiNoteName(normalizedHigh)
  }
}

function midiAtOrAbove(pitch, minimum) {
  return minimum + wrap(pitch - minimum, 12)
}

function midiVoicingInRange(rootIndex, qualityIndex, inversionIndex, low, high, family) {
  var range = normalizeMidiRange(low, high, "")
  var root = noteAt(rootIndex)
  var quality = qualityAt(qualityIndex, family)
  var inversion = wrap(inversionIndex, quality.intervals.length)
  var orderedPitches = []
  for (var i = inversion; i < quality.intervals.length; i++)
    orderedPitches.push(wrap(root.pitch + quality.intervals[i], 12))
  for (var j = 0; j < inversion; j++)
    orderedPitches.push(wrap(root.pitch + quality.intervals[j], 12))

  var first = midiAtOrAbove(orderedPitches[0], range.low)
  var notes = [first]
  for (var noteIndex = 1; noteIndex < orderedPitches.length; noteIndex++)
    notes.push(midiAtOrAbove(orderedPitches[noteIndex], notes[noteIndex - 1] + 1))
  return notes[notes.length - 1] <= range.high ? notes : []
}

function normalizeKeyBindings(value, defaults) {
  var fallback = (defaults || []).slice(0)
  if (!Array.isArray(value) || value.length !== fallback.length)
    return fallback
  var seen = {}
  var result = []
  for (var i = 0; i < value.length; i++) {
    var binding = value[i]
    if (!binding || !isFinite(Number(binding.key)) || typeof binding.label !== "string" || binding.label.length === 0 || seen[String(binding.key)])
      return fallback
    seen[String(binding.key)] = true
    result.push({ key: Math.round(Number(binding.key)), label: binding.label })
  }
  return result
}

function sameKeyBindings(first, second) {
  if (!first || !second || first.length !== second.length)
    return false
  for (var i = 0; i < first.length; i++)
    if (first[i].key !== second[i].key || first[i].label !== second[i].label)
      return false
  return true
}

function rebindKey(bindings, index, replacement) {
  if (!bindings || index < 0 || index >= bindings.length || !replacement)
    return bindings
  var next = bindings.slice(0)
  var duplicate = -1
  for (var i = 0; i < next.length; i++)
    if (i !== index && next[i].key === replacement.key) {
      duplicate = i
      break
    }
  if (duplicate >= 0)
    next[duplicate] = next[index]
  next[index] = { key: replacement.key, label: replacement.label }
  return next
}

function sectorIndexForPitch(pitch) {
  var pc = wrap(pitch, 12)
  for (var i = 0; i < FIFTHS.length; i++)
    if (FIFTHS[i].pitch === pc)
      return i
  return 0
}

var NATURAL_PITCHES = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }
var LETTERS = ["C", "D", "E", "F", "G", "A", "B"]

function spellDegree(rootName, degree, pitch) {
  var rootLetter = rootName.charAt(0)
  var rootLetterIndex = LETTERS.indexOf(rootLetter)
  var targetLetter = LETTERS[wrap(rootLetterIndex + degree - 1, LETTERS.length)]
  var difference = wrap(pitch - NATURAL_PITCHES[targetLetter], 12)
  if (difference > 6)
    difference -= 12
  var accidental = difference === -2 ? "𝄫" : difference === -1 ? "♭" : difference === 1 ? "♯" : difference === 2 ? "𝄪" : ""
  return targetLetter + accidental
}

function chordSpellings(rootIndex, quality, family) {
  var normalizedRootIndex = wrap(rootIndex, FIFTHS.length)
  var spellings = TRIAD_SPELLINGS[quality.triadQualityIndex][normalizedRootIndex].slice(0)
  if (family === "seventh") {
    var rootPitch = noteAt(normalizedRootIndex).pitch
    spellings.push(spellDegree(spellings[0], 7, wrap(rootPitch + quality.intervals[3], 12)))
  }
  return spellings
}

function chord(rootIndex, qualityIndex, inversionIndex, family) {
  var normalizedFamily = family === "seventh" ? "seventh" : "triad"
  var root = noteAt(rootIndex)
  var qualities = qualitiesFor(normalizedFamily)
  var quality = qualityAt(qualityIndex, normalizedFamily)
  var normalizedRootIndex = wrap(rootIndex, FIFTHS.length)
  var normalizedQualityIndex = wrap(qualityIndex, qualities.length)
  var inversion = wrap(inversionIndex, quality.intervals.length)
  var spellings = chordSpellings(normalizedRootIndex, quality, normalizedFamily)
  var pitches = []
  for (var i = 0; i < quality.intervals.length; i++)
    pitches.push(wrap(root.pitch + quality.intervals[i], 12))

  var bass = pitches[inversion]
  var label = spellings[0] + quality.symbol
  if (inversion !== 0)
    label += "/" + spellings[inversion]

  return {
    rootIndex: normalizedRootIndex,
    rootPitch: root.pitch,
    family: normalizedFamily,
    qualityIndex: normalizedQualityIndex,
    inversionIndex: inversion,
    pitches: pitches,
    bass: bass,
    label: label,
    qualityLabel: quality.label,
    inversionLabel: inversionAt(inversion).label,
    spellings: spellings.slice(0),
    noteNames: spellings.join(" · "),
    degrees: quality.degrees.slice(0),
    degreeNames: quality.degrees.join(" · "),
    semitoneNames: quality.intervals.map(interval => interval + 1).join(" · ")
  }
}

function chordRole(chordValue, pitch) {
  if (!chordValue || !chordValue.pitches || !chordValue.degrees)
    return ""
  var normalizedPitch = wrap(pitch, 12)
  for (var i = 0; i < chordValue.pitches.length; i++)
    if (chordValue.pitches[i] === normalizedPitch)
      return chordValue.degrees[i]
  return ""
}

function samePitchSet(a, b) {
  if (!a || !b || a.length !== b.length)
    return false
  for (var i = 0; i < a.length; i++)
    if (!contains(b, a[i]))
      return false
  return true
}

function identifyChord(pitches, bass) {
  if (!pitches || (pitches.length !== 3 && pitches.length !== 4))
    return null
  var family = pitches.length === 4 ? "seventh" : "triad"
  var qualities = qualitiesFor(family)
  var fallback = null
  for (var rootIndex = 0; rootIndex < FIFTHS.length; rootIndex++)
    for (var qualityIndex = 0; qualityIndex < qualities.length; qualityIndex++) {
      var candidate = chord(rootIndex, qualityIndex, 0, family)
      if (samePitchSet(candidate.pitches, pitches)) {
        for (var inversion = 0; inversion < candidate.pitches.length; inversion++)
          if (candidate.pitches[inversion] === bass) {
            var interpreted = chord(rootIndex, qualityIndex, inversion, family)
            if (candidate.rootPitch === bass)
              return interpreted
            if (!fallback)
              fallback = interpreted
          }
      }
    }
  return fallback
}

function identifyTriad(pitches, bass) {
  return pitches && pitches.length === 3 ? identifyChord(pitches, bass) : null
}

function pitchSetNames(pitches) {
  var names = []
  for (var i = 0; i < pitches.length; i++)
    names.push(pitchName(pitches[i]))
  return names.join(" · ")
}

function heldPitchState(entries) {
  var sorted = (entries || []).slice(0)
  sorted.sort(function(a, b) { return a.midi - b.midi })
  var pitches = []
  var midiNotes = []
  for (var i = 0; i < sorted.length; i++) {
    midiNotes.push(sorted[i].midi)
    var pitch = wrap(sorted[i].midi, 12)
    if (!contains(pitches, pitch))
      pitches.push(pitch)
  }
  return {
    pitches: pitches,
    bass: sorted.length > 0 ? wrap(sorted[0].midi, 12) : -1,
    midiNotes: midiNotes
  }
}

function midiVoicing(rootIndex, qualityIndex, inversionIndex, baseMidi, family) {
  var root = noteAt(rootIndex)
  var quality = qualityAt(qualityIndex, family)
  var inversion = wrap(inversionIndex, quality.intervals.length)
  var rangeBase = baseMidi === undefined ? midiForC(4) : Math.round(Number(baseMidi))
  var rootMidi = rangeBase + root.pitch
  var notes = []
  for (var i = inversion; i < quality.intervals.length; i++)
    notes.push(rootMidi + quality.intervals[i])
  for (var j = 0; j < inversion; j++)
    notes.push(rootMidi + quality.intervals[j] + 12)
  return notes
}

function updateHeldKeys(heldKeys, key, note, pressed, autoRepeat) {
  var current = heldKeys || {}
  if (!note || autoRepeat)
    return current

  var id = String(key)
  var alreadyHeld = current[id] !== undefined
  if (pressed === alreadyHeld)
    return current

  var next = {}
  for (var held in current)
    if (pressed || held !== id)
      next[held] = current[held]
  if (pressed)
    next[id] = note
  return next
}

function contains(values, value) {
  for (var i = 0; i < values.length; i++)
    if (values[i] === value)
      return true
  return false
}

function edges(pitches) {
  var result = []
  for (var i = 0; i < pitches.length; i++)
    for (var j = i + 1; j < pitches.length; j++)
      result.push({ a: pitches[i], b: pitches[j] })
  return result
}

function sectorMidDeg(index) {
  return wrap(index, SECTORS) * SECTOR_DEG + TOP_DEG
}

function chromaticMidDeg(pitch) {
  return wrap(pitch, SECTORS) * SECTOR_DEG + TOP_DEG
}

function degToRad(deg) {
  return deg * Math.PI / 180
}

function polarX(cx, radius, deg) {
  return cx + radius * Math.cos(degToRad(deg))
}

function polarY(cy, radius, deg) {
  return cy + radius * Math.sin(degToRad(deg))
}
