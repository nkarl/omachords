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

test("quality formulas produce the expected C triads", () => {
  assert.deepEqual(Array.from(model.chord(0, 0, 0).pitches), [0, 4, 7])
  assert.deepEqual(Array.from(model.chord(0, 1, 0).pitches), [0, 3, 7])
  assert.deepEqual(Array.from(model.chord(0, 2, 0).pitches), [0, 3, 6])
  assert.deepEqual(Array.from(model.chord(0, 3, 0).pitches), [0, 4, 8])
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
