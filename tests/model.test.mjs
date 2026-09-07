import assert from "node:assert/strict"
import fs from "node:fs"
import test from "node:test"
import vm from "node:vm"

const source = fs.readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/u, "")
const model = { Math, Number, isFinite }
vm.createContext(model)
vm.runInContext(source, model)

test("circle follows ascending fifths and contains every pitch class", () => {
  assert.deepEqual(Array.from(model.FIFTHS, note => note.pitch), [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5])
  assert.equal(new Set(Array.from(model.FIFTHS, note => note.pitch)).size, 12)
})

test("chromatic ring follows strict semitone order", () => {
  assert.deepEqual(Array.from(model.CHROMATIC, note => note.pitch), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])
  assert.deepEqual(Array.from(model.CHROMATIC, note => note.label), ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"])
  assert.equal(model.chromaticMidDeg(0), -90)
  assert.equal(model.chromaticMidDeg(1), -60)
  assert.equal(model.chromaticMidDeg(11), 240)
})

test("vocal ranges use scientific pitch notation and a 31-key maximum", () => {
  assert.equal(model.midiNoteName(48), "C3")
  assert.equal(model.midiNoteName(49), "C♯3")
  assert.equal(model.midiNoteName(72), "C5")
  assert.deepEqual({ ...model.normalizeMidiRange(48, 72, "") }, { low: 48, high: 72, count: 25, label: "C3–C5" })
  assert.deepEqual({ ...model.normalizeMidiRange(36, 84, "lower") }, { low: 36, high: 66, count: 31, label: "C2–F♯4" })
  assert.deepEqual({ ...model.normalizeMidiRange(36, 84, "upper") }, { low: 54, high: 84, count: 31, label: "F♯3–C6" })
  assert.deepEqual({ ...model.normalizeMidiRange(20, 100, "lower") }, { low: 36, high: 66, count: 31, label: "C2–F♯4" })
})

test("keyboard rebinding replaces unused keys and swaps duplicates", () => {
  const defaults = [{ key: 65, label: "A" }, { key: 87, label: "W" }, { key: 83, label: "S" }]
  const replaced = Array.from(model.rebindKey(defaults, 0, { key: 90, label: "Z" }))
  assert.deepEqual(replaced.map(binding => ({ ...binding })), [{ key: 90, label: "Z" }, { key: 87, label: "W" }, { key: 83, label: "S" }])
  const swapped = Array.from(model.rebindKey(defaults, 0, { key: 83, label: "S" }))
  assert.deepEqual(swapped.map(binding => ({ ...binding })), [{ key: 83, label: "S" }, { key: 87, label: "W" }, { key: 65, label: "A" }])
  assert.equal(new Set(swapped.map(binding => binding.key)).size, 3)
})

test("persisted keyboard bindings reject malformed or duplicate maps", () => {
  const defaults = [{ key: 65, label: "A" }, { key: 87, label: "W" }]
  const valid = model.normalizeKeyBindings([{ key: 90, label: "Z" }, { key: 88, label: "X" }], defaults)
  assert.deepEqual(Array.from(valid, binding => ({ ...binding })), [{ key: 90, label: "Z" }, { key: 88, label: "X" }])
  assert.deepEqual(Array.from(model.normalizeKeyBindings([{ key: 90, label: "Z" }], defaults)), defaults)
  assert.deepEqual(Array.from(model.normalizeKeyBindings([{ key: 90, label: "Z" }, { key: 90, label: "Z" }], defaults)), defaults)
})

test("persisted key labels have a bounded length without interpreting markup", () => {
  const defaults = [{ key: 65, label: "A" }]
  for (const label of ["<b>A</b>", "X".repeat(model.MAX_KEY_LABEL_LENGTH)]) {
    const result = model.normalizeKeyBindings([{ key: 65, label }], defaults)
    assert.equal(result[0].label, label)
  }
  for (const label of ["", "X".repeat(model.MAX_KEY_LABEL_LENGTH + 1)]) {
    const result = model.normalizeKeyBindings([{ key: 65, label }], defaults)
    assert.equal(result[0].label, "A")
  }
})

test("quality formulas produce the expected C triads", () => {
  assert.deepEqual(Array.from(model.chord(0, 0, 0).pitches), [0, 4, 7])
  assert.deepEqual(Array.from(model.chord(0, 1, 0).pitches), [0, 3, 7])
  assert.deepEqual(Array.from(model.chord(0, 2, 0).pitches), [0, 3, 6])
  assert.deepEqual(Array.from(model.chord(0, 3, 0).pitches), [0, 4, 8])
})

test("comprehensive seventh qualities produce explicit C tetrads", () => {
  const formulas = [
    [0, 4, 7, 11], [0, 4, 7, 10], [0, 3, 7, 10], [0, 3, 6, 10],
    [0, 3, 6, 9], [0, 4, 8, 11], [0, 3, 7, 11]
  ]
  assert.equal(model.SEVENTH_QUALITIES.length, 7)
  for (let qualityIndex = 0; qualityIndex < formulas.length; qualityIndex += 1)
    assert.deepEqual(Array.from(model.chord(0, qualityIndex, 0, "seventh").pitches), formulas[qualityIndex])
  assert.equal(model.chord(0, 0, 0, "seventh").label, "Cmaj7")
  assert.equal(model.chord(0, 1, 0, "seventh").label, "C7")
  assert.equal(model.chord(0, 2, 0, "seventh").label, "Cm7")
  assert.equal(model.chord(0, 3, 0, "seventh").label, "Cm7♭5")
  assert.equal(model.chord(0, 4, 0, "seventh").label, "Cdim7")
  assert.equal(model.chord(0, 5, 0, "seventh").label, "CaugMaj7")
  assert.equal(model.chord(0, 6, 0, "seventh").label, "CmMaj7")
})

test("exclusive quality controls can toggle the active choice off", () => {
  assert.equal(model.toggleExclusiveIndex(0, 0), -1)
  assert.equal(model.toggleExclusiveIndex(-1, 0), 0)
  assert.equal(model.toggleExclusiveIndex(0, 2), 2)
})

test("chords expose scale-degree and semitone analysis", () => {
  const major = model.chord(0, 0, 0)
  assert.equal(major.degreeNames, "1 · 3 · 5")
  assert.equal(major.semitoneNames, "0 · 4 · 7")
  assert.equal(model.chordRole(major, 0), "1")
  assert.equal(model.chordRole(major, 4), "3")
  assert.equal(model.chordRole(major, 7), "5")
  assert.equal(model.chordRole(major, 2), "")
  assert.equal(model.chord(0, 1, 0).degreeNames, "1 · ♭3 · 5")
  assert.equal(model.chord(0, 2, 0).degreeNames, "1 · ♭3 · ♭5")
  assert.equal(model.chord(0, 3, 0).degreeNames, "1 · 3 · ♯5")
  const minorSeventh = model.chord(3, 2, 0, "seventh")
  assert.equal(minorSeventh.label, "Am7")
  assert.equal(minorSeventh.noteNames, "A · C · E · G")
  assert.equal(minorSeventh.degreeNames, "1 · ♭3 · 5 · ♭7")
  assert.equal(minorSeventh.semitoneNames, "0 · 3 · 7 · 10")
})

test("seventh chords support third inversion and four-note recognition", () => {
  const third = model.chord(0, 0, 3, "seventh")
  assert.equal(third.label, "Cmaj7/B")
  assert.equal(third.bass, 11)
  assert.equal(third.inversionLabel, "Third")
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 3, 48, "seventh")), [59, 60, 64, 67])
  assert.deepEqual(Array.from(model.midiVoicingInRange(0, 0, 3, 48, 72, "seventh")), [59, 60, 64, 67])
  assert.equal(model.identifyChord([9, 0, 4, 7], 9).label, "Am7")
  assert.equal(model.identifyChord([11, 0, 4, 7], 11).label, "Cmaj7/B")
  assert.equal(model.edges([0, 4, 7, 11]).length, 6)
})

test("every seventh quality and root produces four distinct pitches", () => {
  for (let rootIndex = 0; rootIndex < 12; rootIndex += 1) {
    for (let qualityIndex = 0; qualityIndex < model.SEVENTH_QUALITIES.length; qualityIndex += 1) {
      const chord = model.chord(rootIndex, qualityIndex, 0, "seventh")
      assert.equal(chord.pitches.length, 4)
      assert.equal(new Set(chord.pitches).size, 4)
      assert.equal(chord.spellings.length, 4)
    }
  }
})

test("every seventh inversion fits atomically inside a 31-key range", () => {
  for (let rootIndex = 0; rootIndex < 12; rootIndex += 1) {
    for (let qualityIndex = 0; qualityIndex < model.SEVENTH_QUALITIES.length; qualityIndex += 1) {
      for (let inversionIndex = 0; inversionIndex < 4; inversionIndex += 1) {
        const notes = Array.from(model.midiVoicingInRange(rootIndex, qualityIndex, inversionIndex, 36, 66, "seventh"))
        assert.equal(notes.length, 4)
        assert.ok(notes[0] >= 36)
        assert.ok(notes[3] <= 66)
        assert.ok(notes[0] < notes[1] && notes[1] < notes[2] && notes[2] < notes[3])
        assert.equal(model.wrap(notes[0], 12), model.chord(rootIndex, qualityIndex, inversionIndex, "seventh").bass)
      }
    }
  }
})

test("every root and quality produces three distinct formula pitches", () => {
  const formulas = [[0, 4, 7], [0, 3, 7], [0, 3, 6], [0, 4, 8]]
  for (let rootIndex = 0; rootIndex < 12; rootIndex += 1) {
    for (let qualityIndex = 0; qualityIndex < formulas.length; qualityIndex += 1) {
      const chord = model.chord(rootIndex, qualityIndex, 0)
      const expected = formulas[qualityIndex].map(interval => model.wrap(chord.rootPitch + interval, 12))
      assert.deepEqual(Array.from(chord.pitches), expected)
      assert.equal(new Set(chord.pitches).size, 3)
    }
  }
})

test("note names use coherent enharmonic spelling", () => {
  assert.equal(model.chord(6, 0, 0).noteNames, "F♯ · A♯ · C♯")
  assert.equal(model.chord(7, 1, 0).noteNames, "C♯ · E · G♯")
  assert.equal(model.chord(7, 1, 1).label, "C♯m/E")
})

test("inversion changes bass and label but not the pitch-class graph", () => {
  const root = model.chord(0, 0, 0)
  const first = model.chord(0, 0, 1)
  const second = model.chord(0, 0, 2)
  assert.deepEqual(Array.from(first.pitches), Array.from(root.pitches))
  assert.deepEqual(Array.from(second.pitches), Array.from(root.pitches))
  assert.equal(root.bass, 0)
  assert.equal(first.bass, 4)
  assert.equal(second.bass, 7)
  assert.equal(first.label, "C/E")
  assert.equal(second.label, "C/G")
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 0)), [60, 64, 67])
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 1)), [64, 67, 72])
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 2)), [67, 72, 76])
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 0, 48)), [48, 52, 55])
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 1, 48)), [52, 55, 60])
  assert.deepEqual(Array.from(model.midiVoicing(0, 0, 2, 48)), [55, 60, 64])
  assert.deepEqual(Array.from(model.midiVoicingInRange(0, 0, 0, 48, 72)), [48, 52, 55])
  assert.deepEqual(Array.from(model.midiVoicingInRange(0, 0, 1, 48, 72)), [52, 55, 60])
  assert.deepEqual(Array.from(model.midiVoicingInRange(0, 0, 2, 48, 72)), [55, 60, 64])
  assert.deepEqual(Array.from(model.midiVoicingInRange(0, 0, 0, 48, 54)), [])
})

test("every fitted inversion stays ascending and inside the selected range", () => {
  for (let rootIndex = 0; rootIndex < 12; rootIndex += 1) {
    for (let qualityIndex = 0; qualityIndex < 4; qualityIndex += 1) {
      for (let inversionIndex = 0; inversionIndex < 3; inversionIndex += 1) {
        const notes = Array.from(model.midiVoicingInRange(rootIndex, qualityIndex, inversionIndex, 36, 66))
        assert.equal(notes.length, 3)
        assert.ok(notes[0] >= 36)
        assert.ok(notes[2] <= 66)
        assert.ok(notes[0] < notes[1] && notes[1] < notes[2])
        assert.equal(model.wrap(notes[0], 12), model.chord(rootIndex, qualityIndex, inversionIndex).bass)
      }
    }
  }
})

test("held pitch classes are identified independently of key order", () => {
  assert.equal(model.identifyTriad([7, 0, 4], 0).label, "C")
  assert.equal(model.identifyTriad([4, 7, 0], 4).label, "C/E")
  assert.equal(model.identifyTriad([7, 4, 0], 7).label, "C/G")
  assert.equal(model.identifyTriad([0, 5], 0), null)
})

test("held notes collapse octave duplicates without losing the lowest bass", () => {
  const state = model.heldPitchState([{ midi: 72 }, { midi: 67 }, { midi: 60 }, { midi: 64 }])
  assert.deepEqual(Array.from(state.pitches), [0, 4, 7])
  assert.equal(state.bass, 0)
  const afterLowerCRelease = model.heldPitchState([{ midi: 72 }, { midi: 67 }, { midi: 64 }])
  assert.deepEqual(Array.from(afterLowerCRelease.pitches), [4, 7, 0])
  assert.equal(afterLowerCRelease.bass, 4)
})

test("held-key transitions ignore repeats and duplicate events", () => {
  const s = { note: "D4", midi: 62 }
  const f = { note: "F4", midi: 65 }
  const h = { note: "A4", midi: 69 }
  let held = {}

  held = model.updateHeldKeys(held, 83, s, true, false)
  held = model.updateHeldKeys(held, 70, f, true, false)
  held = model.updateHeldKeys(held, 72, h, true, false)
  const triad = held

  assert.equal(model.updateHeldKeys(held, 72, h, true, true), triad)
  assert.equal(model.updateHeldKeys(held, 72, h, false, true), triad)
  assert.equal(model.updateHeldKeys(held, 72, h, true, false), triad)
  const state = model.heldPitchState(Object.values(held))
  assert.deepEqual(Array.from(state.pitches), [2, 5, 9])
  assert.equal(state.bass, 2)

  held = model.updateHeldKeys(held, 83, s, false, false)
  held = model.updateHeldKeys(held, 70, f, false, false)
  held = model.updateHeldKeys(held, 72, h, false, false)
  assert.deepEqual(Object.keys(held), [])
  assert.equal(model.updateHeldKeys(held, 72, h, false, false), held)
})

test("A is immediately visible alone and A-D-G produces C major", () => {
  const a = { note: "C4", midi: 60 }
  const d = { note: "E4", midi: 64 }
  const g = { note: "G4", midi: 67 }
  let held = model.updateHeldKeys({}, 65, a, true, false)
  let state = model.heldPitchState(Object.values(held))
  assert.deepEqual(Array.from(state.pitches), [0])

  held = model.updateHeldKeys(held, 68, d, true, false)
  held = model.updateHeldKeys(held, 71, g, true, false)
  state = model.heldPitchState(Object.values(held))
  assert.deepEqual(Array.from(state.pitches), [0, 4, 7])
  assert.equal(model.identifyTriad(state.pitches, state.bass).label, "C")
})

test("a triad produces three undirected edges", () => {
  const edges = model.edges([0, 4, 7])
  assert.equal(edges.length, 3)
  assert.deepEqual(Array.from(edges, edge => [edge.a, edge.b]), [[0, 4], [0, 7], [4, 7]])
})
