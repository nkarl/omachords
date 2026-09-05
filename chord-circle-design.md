# Chord Circle Plugin Design

## Status

Draft. This document defines the product and implementation direction but does not authorize implementation.

## Purpose

Chord Circle is an Omarchy Quattro plugin for practicing chord structure through two connected forms of feedback: seeing which pitch classes compose a chord and hearing the chord.

The plugin is not a piano, sequencer, or four-part voicing tool. A chord is modeled primarily as a set of pitch classes. Root position and inversions therefore share the same graph; octave placement and the lowest sounding note belong to playback presentation rather than chord identity.

## Goals

- Make the internal interval structure of a chord immediately visible.
- Select a root, triad quality, and inversion through direct controls.
- Use the same two-octave computer-keyboard layout as Quick Piano to activate pitch classes while keys are held.
- Show similarities and differences between consecutive chords.
- Play all active notes as one synchronized chord through a stable audio stream.
- Sustain common tones smoothly when the chord changes.
- Fit naturally into the Omarchy Quattro bar-and-panel interaction model.

## Non-goals

- SATB voice assignment or voice-leading analysis.
- A piano-keyboard interface.
- MIDI recording, sequencing, notation, or score playback.
- A complete harmonic-analysis system.
- Instrument emulation or high-fidelity sampled piano sound.
- Distinguishing inversions in the structural graph.

## Core musical model

The canonical preset state is a root pitch class, one of four triad qualities, and one of three inversions. The model derives exactly three pitch classes from that selection. Keyboard mode is independent and momentary: the graph is exactly the pitch classes represented by currently held piano keys, including zero, one, or two notes. Supporting saved free-form pitch sets, seventh-chord presets, extensions, and clusters is deferred.

The circle contains twelve pitch-class nodes ordered by ascending fifths:

```text
C · G · D · A · E · B · F♯/G♭ · D♭/C♯ · A♭/G♯ · E♭/D♯ · B♭/A♯ · F
```

Enharmonic notes such as F♯ and G♭ share one pitch-class node. Each node shows a concise pitch label and its primary lower-octave computer-key binding, while deterministic triad construction chooses a context-appropriate spelling for the center readout.

The active pitch classes are nodes. An edge joins every pair of active nodes. Three notes form a triangle whose geometry remains unchanged across inversions. The graph is descriptive rather than directional: an edge means that two pitch classes coexist in the chord.

## Chord state

The UI owns a single state object independent of rendering and audio:

```text
current.root           selected fifths-sector index, 0–11
current.quality        major, minor, diminished, or augmented
current.inversion      root, first, or second
current.pitchClasses   three derived pitch classes
current.bass           pitch class derived from the inversion
held.keys              physical piano keys currently held
held.pitchClasses      unique pitch classes derived modulo 12
held.bass              pitch class of the lowest held keyboard note
revision               monotonically increasing change identifier
```

Changes should be committed atomically. Selecting a root, quality, or inversion produces one new revision. Inversion changes the bass and playback label without changing the pitch-class graph.

Keyboard input follows Quick Piano exactly. White notes use `A S D F G H J K L ; ' Z X C V`; black notes use `W E T Y U O P [ ] \`. A deterministic held-key transition accepts each physical press or release exactly once and rejects Qt-marked auto-repeat events and duplicate transitions. Every accepted press updates the graph immediately, so a single key shows one node and a partial combination shows its current nodes and edges. Every accepted release removes only that key; releasing all keys leaves the keyboard graph empty. Pointer selection of a root, quality, or inversion exits keyboard mode and displays the selected preset.

No musical selection cycles from the keyboard: a mapped piano key always resolves to one fixed note, and repeating the same combination always produces the same pitch-class set and chord identity. Root, quality, and inversion presets are changed with the pointer controls rather than cycling shortcuts.

## Chord identity

Chord identity is derived deterministically from the selected root and quality. Later additions may include suspended triads, seventh chords, extensions, free-form pitch selection, and chord detection for those broader inputs.

The center of the circle displays:

- The constructed chord name, such as `C major` or `A minor`.
- The active note names, such as `C · E · G`.

Inversion may be displayed as a slash name such as `C/E` when a playback bass is selected, but it does not alter the nodes or edges.

## Plugin shape

The preferred form is a large, centered, keyboard-exclusive overlay window that stays independent of the status bar and is toggled directly through the Omarchy shell.

Suggested files after implementation begins:

```text
manifest.json
Panel.qml
Model.js
synth.py
tests/
```

The UI and engine communicate through a narrow protocol so that the UI milestone can be completed with a mock transport before audio exists.

# Milestone 1: UI and Musical Model

## Outcome

Deliver a complete silent chord-exploration overlay. A user can construct chords and understand their pitch composition without an audio engine.

## Scope

### Circular graph

- Render twelve equally spaced circular nodes in fifths order without an annular sector band.
- Give every node a stable pitch-class identity, concise enharmonic label, and primary computer-key label.
- Select a preset root with a primary click directly on its node.
- Connect every pair of active nodes with an edge.
- Derive exactly three active nodes from a preset root and quality while allowing keyboard mode to display any number of held pitch classes.
- Keep edges behind nodes and labels.
- Scale cleanly within the large overlay window without clipping labels or hit targets.

### Piano-key input

- Match the complete `max.piano` keyboard mapping from C4 through C6.
- Activate nodes on key press and deactivate them on key release.
- Reduce keyboard notes modulo 12 for the circular display.
- Reference-count equivalent pitch classes so octave duplicates do not release a node prematurely.
- Draw edges between every pair of held pitch classes.
- Identify supported triads independently of the order in which their keys were pressed.
- Show the inversion implied by the lowest held keyboard note.
- Show exactly the currently held pitch classes, including individual notes and partial combinations.

### Chord identity

- Construct major, minor, diminished, and augmented triads from interval formulas.
- Display the constructed chord name and active note names in the center.
- Treat inversions as the same structural chord.
- Display root, first, and second inversions with the appropriate bass and slash label.

### Interaction and accessibility

- Support mouse selection and keyboard navigation.
- Provide visible hover and keyboard-focus states.
- Make Escape close the panel through the standard Quattro panel behavior.
- Prevent key auto-repeat from applying repeated toggles.
- Derive colors, spacing, and typography from Omarchy style primitives.
- Avoid encoding state by color alone.

### Engine boundary

Define UI calls without implementing sound:

```text
engine.start()
engine.setChord(revision, pitches, bass)
engine.stopChord(revision)
engine.shutdown()
```

During this milestone, a mock adapter records commands and exposes engine status to the UI. No detached player processes should be introduced as a temporary audio solution.

## UI state transitions

Every committed preset edit follows this sequence:

```text
user action
  → validate requested pitch-set change
  → commit new current state and revision
  → recompute the chord label and graph
```

Pressing Play sends the current revision, all three derived pitch classes, and the inversion-derived bass to the engine adapter in one `setChord` call. Selection changes do not play automatically. Hover and focus are transient presentation changes and must not create chord revisions.

## UI tests

- Fifths-order index and pitch-class mapping.
- Root selection across all twelve fifths-ordered nodes.
- Quality and inversion transitions.
- Piano key press, release, auto-repeat suppression, and duplicate-octave handling.
- Enharmonic node labels mapped to a single pitch identity.
- Triad construction for every root and supported quality.
- Inversion-invariant pitch-class graphs and inversion-specific bass values.
- Graph edge generation for every supported triad.
- One atomic `setChord` command per Play action, containing the current revision, all three pitches, and the bass.
- Direct node hit targets and hover behavior.
- Keyboard navigation and auto-repeat rejection.

## Acceptance criteria

- Every root can be combined with major, minor, diminished, or augmented quality.
- Root, first, and second inversion produce the same three nodes and edges while changing the bass and slash label.
- Holding any `max.piano` key activates the corresponding pitch-class node; holding a triad draws its three-node shape.
- Releasing one of two held octave-equivalent keys leaves their shared node active.
- Three active pitch classes produce exactly three undirected edges.
- Changing the root or quality changes the graph and label in one visible action.
- Moving between two chords clearly identifies shared and changed structure.
- The overlay validates as an Omarchy plugin and scales within the active output while remaining independent of bar position and orientation.
- The mock engine log proves that each Play action sends the complete chord state atomically.

## Explicitly deferred

- Sound generation.
- PipeWire process management.
- Attack, sustain, and release behavior.
- Audio recovery and shutdown behavior.
- Free-form note activation, seventh chords, extensions, and clusters.

# Milestone 2: Persistent Synth Engine

## Outcome

Replace the mock adapter with one persistent synth process that plays the complete pitch-class set through one continuous PipeWire stream, without the fixed-duration and per-note process behavior of Quick Piano.

## Process architecture

Quickshell starts one `synth.py` process when audio is first needed. The synth starts and owns one long-lived raw PCM player, preferably `pw-play`, and continuously writes mixed audio frames to it. Quickshell does not spawn a player for each note or chord.

```text
Quickshell panel
  ↔ command/status channel
persistent synth.py
  → one raw PCM stream
persistent pw-play
  → PipeWire
```

The synth maintains up to twelve internal pitch-class voices. These are oscillator and envelope states inside one process, not operating-system processes and not independently scheduled PipeWire streams.

## Command protocol

Use newline-delimited JSON over standard input and standard output. Commands must be versioned and processed in order.

Example commands:

```json
{"v":1,"cmd":"set_chord","revision":12,"pitches":[0,4,7],"bass":0}
{"v":1,"cmd":"stop","revision":13}
{"v":1,"cmd":"shutdown"}
```

Example status messages:

```json
{"v":1,"event":"ready"}
{"v":1,"event":"applied","revision":12}
{"v":1,"event":"error","message":"pw-play exited"}
```

`set_chord` is atomic: all added and removed pitches enter their envelope transitions at the same audio-frame boundary. Duplicate pitches are rejected or normalized before application. A stale revision must not replace a newer chord.

## Synthesis behavior

- Use one oscillator state per active pitch class.
- Assign a deterministic playback octave to each pitch class, with optional bass placement stored separately from graph identity.
- Start added pitches with a short click-free attack.
- Move removed pitches through a short release rather than cutting them immediately.
- Keep unchanged pitches active without resetting phase or envelope.
- Normalize or limit aggregate gain according to active-note count.
- End every released oscillator at or near a zero crossing through its envelope.
- Render fixed-size blocks continuously rather than precomputing a fixed-duration sample.

The initial timbre should be deliberately simple and stable. A sine wave with a restrained harmonic component is preferable to detuned oscillators until overlap, clipping, and long-duration behavior are proven clean.

## Lifecycle

- Start lazily on the first play request.
- Wait for a `ready` event before treating audio as available.
- Send the latest complete chord after startup or restart.
- Send `stop` when playback is disabled or the panel requests silence.
- Send `shutdown` when the plugin is unloaded, then terminate after a short grace period if necessary.
- Detect unexpected synth or `pw-play` exit and show a non-blocking unavailable state.
- Permit one bounded automatic restart; avoid an unlimited crash loop.
- Guarantee that at most one synth worker and one child player belong to the plugin.

Closing the panel should default to silencing the chord while keeping the synth process available for the next opening. Plugin unload must end both processes.

## Audio/UI integration

- A Play action sends exactly one `set_chord` command for the current UI revision.
- The visible sounding state follows the last acknowledged revision, not merely the last requested revision.
- Audio failure must not prevent silent chord exploration.
- Rapid edits may coalesce before transmission, but the engine must never receive a partially updated chord.
- The UI should expose a clear sound toggle and a compact engine-error indicator.

## Engine tests

- Protocol parsing, validation, and revision ordering.
- Atomic activation of all notes in a chord.
- Retention of common tones without phase or envelope reset.
- Attack and release continuity at block boundaries.
- Zero, one, three, and twelve active pitch classes.
- Duplicate pitch normalization.
- Gain behavior and clipping prevention at maximum activation.
- Indefinite sustain without a 1.8-second or other fixed cutoff.
- Rapid chord replacement and stop/start sequences.
- Broken pipe, player exit, engine restart, and graceful shutdown.
- No orphan synth or `pw-play` process after plugin unload.

## Acceptance criteria

- A held chord remains stable for at least ten minutes without periodic restart, dropout, or accumulated drift.
- A triad begins as one synchronized engine update.
- Common tones remain continuous when changing between related chords.
- Added and removed notes transition without audible clicks or screeching.
- Twelve active pitch classes do not clip under the default gain policy.
- Rapid UI changes do not create overlapping synth or `pw-play` processes.
- Only one synth worker and one audio stream exist during normal operation.
- Killing the audio player produces a visible error and bounded recovery rather than a silent process storm.

## Milestone dependency and delivery boundary

Milestone 1 defines the musical state and the complete user interaction. Its mock engine contract is the sole integration boundary for Milestone 2. Engine work should not require redesigning node identity, triad construction, or inversion semantics.

Milestone 1 is complete when the silent panel is independently useful and validated. Milestone 2 is complete when the mock adapter has been replaced, the audio lifecycle passes its tests, and sustained chord changes are audibly smooth.

## Open design decisions

- Whether playback uses one fixed register or an optional bass/inversion selector.
- Whether closing the panel always silences playback or a user setting may allow continued sound.
