.pragma library

var SECTORS = 12
var SECTOR_DEG = 360 / SECTORS
var TOP_DEG = -90

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

var QUALITIES = [
  { id: "major", label: "Major", symbol: "", intervals: [0, 4, 7] },
  { id: "minor", label: "Minor", symbol: "m", intervals: [0, 3, 7] },
  { id: "diminished", label: "Diminished", symbol: "dim", intervals: [0, 3, 6] },
  { id: "augmented", label: "Augmented", symbol: "aug", intervals: [0, 4, 8] }
]

var INVERSIONS = [
  { id: "root", label: "Root", shortLabel: "R" },
  { id: "first", label: "First", shortLabel: "1st" },
  { id: "second", label: "Second", shortLabel: "2nd" }
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

function qualityAt(index) {
  return QUALITIES[wrap(index, QUALITIES.length)]
}

function inversionAt(index) {
  return INVERSIONS[wrap(index, INVERSIONS.length)]
}

function pitchName(pitch) {
  return FLAT_NAMES[wrap(pitch, 12)]
}

function sectorIndexForPitch(pitch) {
  var pc = wrap(pitch, 12)
  for (var i = 0; i < FIFTHS.length; i++)
    if (FIFTHS[i].pitch === pc)
      return i
  return 0
}

function chord(rootIndex, qualityIndex, inversionIndex) {
  var root = noteAt(rootIndex)
  var quality = qualityAt(qualityIndex)
  var normalizedRootIndex = wrap(rootIndex, FIFTHS.length)
  var normalizedQualityIndex = wrap(qualityIndex, QUALITIES.length)
  var inversion = wrap(inversionIndex, INVERSIONS.length)
  var spellings = TRIAD_SPELLINGS[normalizedQualityIndex][normalizedRootIndex]
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
    qualityIndex: normalizedQualityIndex,
    inversionIndex: inversion,
    pitches: pitches,
    bass: bass,
    label: label,
    qualityLabel: quality.label,
    inversionLabel: inversionAt(inversion).label,
    spellings: spellings.slice(0),
    noteNames: spellings[0] + " · " + spellings[1] + " · " + spellings[2]
  }
}

function samePitchSet(a, b) {
  if (!a || !b || a.length !== b.length)
    return false
  for (var i = 0; i < a.length; i++)
    if (!contains(b, a[i]))
      return false
  return true
}

function identifyTriad(pitches, bass) {
  if (!pitches || pitches.length !== 3)
    return null
  for (var rootIndex = 0; rootIndex < FIFTHS.length; rootIndex++)
    for (var qualityIndex = 0; qualityIndex < QUALITIES.length; qualityIndex++) {
      var candidate = chord(rootIndex, qualityIndex, 0)
      if (samePitchSet(candidate.pitches, pitches)) {
        for (var inversion = 0; inversion < candidate.pitches.length; inversion++)
          if (candidate.pitches[inversion] === bass)
            return chord(rootIndex, qualityIndex, inversion)
        return candidate
      }
    }
  return null
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
  for (var i = 0; i < sorted.length; i++) {
    var pitch = wrap(sorted[i].midi, 12)
    if (!contains(pitches, pitch))
      pitches.push(pitch)
  }
  return {
    pitches: pitches,
    bass: sorted.length > 0 ? wrap(sorted[0].midi, 12) : -1
  }
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

function degToRad(deg) {
  return deg * Math.PI / 180
}

function polarX(cx, radius, deg) {
  return cx + radius * Math.cos(degToRad(deg))
}

function polarY(cy, radius, deg) {
  return cy + radius * Math.sin(degToRad(deg))
}
