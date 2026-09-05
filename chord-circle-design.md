# Chord Circle Plugin Design

## Status

Implemented through Milestone 2. This document records the product contract, architecture, and failure policy.

## Purpose

Chord Circle is an Omarchy Quattro plugin for practicing chord structure through two connected forms of feedback: seeing which pitch classes compose a chord and hearing the chord.

The plugin is not a piano, sequencer, or four-part voicing tool. A chord is modeled primarily as a set of pitch classes. Root position and inversions therefore share the same graph; octave placement and the lowest sounding note belong to playback presentation rather than chord identity.

## Goals

- Make the internal interval structure of a chord immediately visible.
- Select a root and triad quality through direct controls, then audition root position, first inversion, or second inversion.
- Use up to 31 computer keys as a contiguous chromatic keyboard range to activate pitch classes while keys are held.
- Show similarities and differences between consecutive chords.
- Play all active notes as one synchronized chord through a stable audio stream.
- Sustain common tones smoothly when the chord changes.
- Fit naturally into the Omarchy Quattro overlay model while remaining independent of the bar.

## Non-goals

- SATB voice assignment or voice-leading analysis.
- A piano-keyboard interface.
- MIDI recording, sequencing, notation, or score playback.
- A complete harmonic-analysis system.
- Instrument emulation or high-fidelity sampled piano sound.
- Distinguishing inversions in the structural graph.

## Core musical model

The canonical preset state is a root pitch class and one of four triad qualities. The model derives exactly three persistent pitch classes from that selection. Keyboard state is independent and momentary: currently held piano keys add a second visual layer without replacing or modifying the preset. Root position, first inversion, and second inversion are playback choices for the preset rather than structural graph modes. Supporting saved free-form pitch sets, seventh-chord presets, extensions, and clusters is deferred.

The circle contains twelve pitch-class nodes ordered by ascending fifths:

```text
C · G · D · A · E · B · F♯/G♭ · D♭/C♯ · A♭/G♯ · E♭/D♯ · B♭/A♯ · F
```

Enharmonic notes such as F♯ and G♭ share one pitch-class node. Each node shows a concise pitch label and its primary lower-octave computer-key binding, while deterministic triad construction chooses a context-appropriate spelling for the center readout.

The persistent preset pitch classes are accent-colored nodes joined by accent edges. The selected root has a white border. Held keyboard pitch classes add a white glow and white edges for the duration of the press, including when they coincide with preset nodes. Three notes form a triangle whose geometry remains unchanged across inversions. The graph is descriptive rather than directional: an edge means that two pitch classes coexist in one layer.

An outer chromatic ring presents the same twelve pitch classes clockwise in strict semitone order from C through B. Every preset or held pitch activates its corresponding position on both rings, revealing tonal proximity and interval distance at once. Only the inner tonal space draws edges: chromatic ordering is visually self-evident, and omitting a second graph prevents unnecessary density. The chromatic ring consists of twelve narrow annular beams with substantial radial length and clear angular separation. Each fill and outline uses a radial alpha gradient: intensity is greatest at the beam's inner edge and falls continuously into the overlay background toward its outer end. Inactive beams use a quiet neutral shade, preset chord tones use a low-opacity accent shade, and held notes add a temporary low-opacity white wash and outline. The selected preset root retains a stronger white outline on the outer ring, distinguishing it from the third and fifth even when a held-note layer overlaps it. These treatments reproduce the inner ring's independent persistent and momentary states at lower intensity so the inner graph remains the primary focus.

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
settings.rangeLowMidi  inclusive lower note of the performance range
settings.rangeHighMidi inclusive upper note of the performance range
settings.keyBindings   ordered one-to-one map of physical keys to range positions
revision               monotonically increasing change identifier
```

Selecting a root or quality updates the persistent triad atomically. Choosing an inversion sends one complete audition command with the corresponding bass without changing the pitch-class graph.

Keyboard input preserves Quick Piano's physical layout and extends it to 31 contiguous semitones. Notes ascend across `A W S E D F T G Y H U J K O L P ; ' [ Z ] X \ C V B N M , . /`. A deterministic held-key transition accepts each physical press or release exactly once and rejects Qt-marked auto-repeat events and duplicate transitions. Every accepted press immediately adds a glow and any held-note edges over the persistent triad. Every accepted release removes only that momentary contribution. Pointer selection and keyboard performance never clear or rewrite one another.

The settings modal exposes independent lower and upper semitone handles over the global C2–C6 span. The selected range is inclusive and limited to 31 notes, equivalent to 2.5 octaves; moving either handle past that width shifts the other bound. C3–C5 is the default, and selecting fewer notes disables unused keys at the end of the 31-key mapping. Opening the modal silences current computer-key notes and any timed audition before remapping them, preventing old-register audio or stale MIDI notes. The plugin persists `rangeLowMidi` and `rangeHighMidi` in its top-level `shell.json` entry and migrates the earlier `keyboardBaseOctave` setting when present.

The same modal exposes all 31 ordered key slots for rebinding. Selecting a slot captures the next non-modifier key; if that key already belongs to another slot, the bindings swap rather than creating an ambiguous duplicate. Inactive slots remain editable for later range expansion. The `keyBindings` array persists with the range, malformed or duplicate saved maps fall back atomically to the default layout, and Reset restores all 31 defaults.

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
EngineAdapter.qml
engine/Cargo.toml
engine/src/main.rs
tests/
```

The UI and engine communicate through a narrow protocol so that the UI milestone can be completed with a mock transport before audio exists.

# Milestone 1: UI and Musical Model

## Outcome

Deliver a complete silent chord-exploration overlay. A user can construct chords and understand their pitch composition without an audio engine.

## Scope

### Circular graph

- Render twelve equally spaced interactive circular nodes in fifths order.
- Render a coordinated outer ring of twelve narrow, radially elongated beams in strict chromatic order.
- Give every node a stable pitch-class identity, concise enharmonic label, and primary computer-key label.
- Select a preset root with a primary click directly on its node.
- Connect every pair of active nodes with an edge.
- Draw graph edges only in the inner tonal circle; never connect outer chromatic blocks.
- Activate the matching position on both rings for every preset or held pitch class.
- Keep preset activation persistent and held-note activation momentary on both rings.
- Distinguish the selected preset root from the other two chord tones on both rings.
- Fade every outer beam from higher intensity near the tonal circle to full transparency at its outer end.
- Derive exactly three persistent accent-colored nodes from a preset root and quality while allowing any number of held pitch classes to appear as a momentary white layer.
- Keep edges behind nodes and labels.
- Scale cleanly within the large overlay window without clipping labels or hit targets.

### Piano-key input

- Map up to 31 computer keys chromatically from the selected lower bound.
- Activate nodes on key press and deactivate them on key release.
- Reduce keyboard notes modulo 12 for the circular display.
- Reference-count equivalent pitch classes so octave duplicates do not release a node prematurely.
- Draw edges between every pair of held pitch classes.
- Identify supported triads independently of the order in which their keys were pressed.
- Show the inversion implied by the lowest held keyboard note.
- Show exactly the currently held pitch classes, including individual notes and partial combinations.
- Apply the configured C2–C6 bounded range to both computer-key MIDI notes and preset inversion auditions.

### Chord identity

- Construct major, minor, diminished, and augmented triads from interval formulas.
- Display the constructed chord name and active note names in the center.
- Treat inversions as the same structural chord.
- Make root, first, and second inversion controls audition the persistent triad with the appropriate bass and slash label.

### Interaction and accessibility

- Support mouse selection and keyboard navigation.
- Provide visible hover and keyboard-focus states.
- Place the Quality and Inversion control groups side by side so they consume one shared horizontal control row.
- Provide a dual-bound semitone range slider whose persisted choice and active key count are visible from the main overlay.
- Allow every keyboard slot to be rebound, swap duplicate assignments, and restore the complete default map.
- Make Escape close the overlay through the standard Quattro overlay behavior.
- Prevent key auto-repeat from applying repeated toggles.
- Derive colors, spacing, and typography from Omarchy style primitives.
- Avoid encoding state by color alone.

### Engine boundary

The UI-to-engine boundary exposes:

```text
engine.setHeld(revision, midiNotes)
engine.audition(revision, midiNotes, durationMs)
engine.stop(revision)
```

A mock adapter tests this boundary independently of the native engine.

## UI state transitions

Every committed preset edit follows this sequence:

```text
user action
  → validate requested pitch-set change
  → commit new current state and revision
  → recompute the chord label and graph
```

Pressing an inversion button sends the current preset's complete MIDI voicing to the engine adapter in one `audition` call. Root and quality selection do not play automatically. Hover and focus are transient presentation changes and must not create engine commands.

## UI tests

- Fifths-order index and pitch-class mapping.
- Root selection across all twelve fifths-ordered nodes.
- Quality transitions and inversion audition commands.
- Piano key press, release, auto-repeat suppression, and duplicate-octave handling.
- Keyboard binding capture, duplicate-key swapping, reset, validation, and persistence.
- Enharmonic node labels mapped to a single pitch identity.
- Triad construction for every root and supported quality.
- Inversion-invariant pitch-class graphs and inversion-specific bass values.
- Graph edge generation for every supported triad.
- One atomic `audition` command per inversion-button action, containing the current revision, all three concrete MIDI notes, and the duration.
- Direct node hit targets and hover behavior.
- Keyboard navigation and auto-repeat rejection.

## Acceptance criteria

- Every root can be combined with major, minor, diminished, or augmented quality.
- Root, first, and second inversion produce the same three nodes and edges while changing the bass and slash label.
- Holding any active mapped key activates the corresponding pitch-class node; holding a triad draws its three-node shape.
- Releasing one of two held octave-equivalent keys leaves their shared node active.
- Three active pitch classes produce exactly three undirected edges.
- Changing the root or quality changes the graph and label in one visible action.
- The overlay validates as an Omarchy plugin and scales within the active output while remaining independent of bar position and orientation.
- The mock engine log proves that each inversion audition sends one complete MIDI voicing atomically.

## Explicitly deferred

- Free-form preset construction, seventh chords, extensions, and clusters.

# Milestone 2: Persistent Synth Engine

## Outcome

Use one persistent Rust synth process and one CPAL output stream, without the fixed-duration and per-note process behavior of Quick Piano.

## Process architecture

Quickshell starts one `chord-circle-engine` process when audio is first needed. CPAL owns one long-lived callback-driven output stream that reaches the system PipeWire service through the Linux audio stack. Quickshell does not spawn a player for each note or chord.

```text
Quickshell overlay
  ↔ command/status channel
persistent Rust engine
  → one CPAL audio stream
  → PipeWire
```

The synth maintains 128 fixed MIDI voice slots. These are oscillator and envelope states inside one process, not operating-system processes and not independently scheduled audio streams.

## Command protocol

Use newline-delimited JSON over standard input and standard output. Commands must be versioned and processed in order.

Example commands:

```json
{"v":1,"cmd":"set_held","revision":12,"notes":[60,64,67]}
{"v":1,"cmd":"audition","revision":13,"notes":[64,67,72],"duration_ms":900}
{"v":1,"cmd":"stop","revision":13}
{"v":1,"cmd":"shutdown"}
```

Example status messages:

```json
{"event":"ready","rate":48000,"channels":2}
{"v":1,"event":"applied","revision":12}
{"event":"error","message":"audio stream unavailable"}
```

The control path publishes held and audition notes through atomic MIDI bitsets. The realtime callback reads those bitsets at buffer boundaries, so JSON parsing, allocation, process management, and mutex locking stay outside the audio path. Held notes and timed auditions are independent sources whose union drives the voices.

Preset voicings use the lowest occurrence of the requested inversion bass that permits the complete ascending triad to fit inside the selected lower and upper bounds. No chord tone is dropped or folded when the range is too narrow; the overlay reports that the inversion does not fit instead. This preserves the same three pitch classes while aligning auditions with the singer's chosen register.

## Synthesis behavior

- Use one oscillator state per MIDI note.
- Use concrete ascending MIDI voicings for root position, first inversion, and second inversion.
- Start added pitches with a short click-free attack.
- Move removed pitches through a short release rather than cutting them immediately.
- Keep unchanged pitches active without resetting phase or envelope.
- Normalize or limit aggregate gain according to active-note count.
- End every released oscillator smoothly through its envelope.
- Render fixed-size blocks continuously rather than precomputing a fixed-duration sample.

The initial timbre should be deliberately simple and stable. A sine wave with a restrained harmonic component is preferable to detuned oscillators until overlap, clipping, and long-duration behavior are proven clean.

## Lifecycle

- Start lazily on the first play request.
- Wait for a `ready` event before treating audio as available.
- Queue commands until the engine reports `ready`.
- Send `stop` when playback is disabled or the overlay requests silence.
- Send `shutdown` when the plugin is unloaded and terminate the process as part of teardown.
- Detect unexpected engine exit and show a non-blocking unavailable state.
- Restart only when a later user action requests audio; avoid an automatic crash loop.
- Guarantee that at most one synth process and one CPAL stream belong to the plugin.

Closing the overlay silences held notes while keeping the synth process available for the next opening. Plugin unload must end the engine process and its CPAL stream.

### Failure containment and user-triggered recovery

The engine adapter treats a failed process as unavailable state, not as a signal to start another process automatically. Startup errors, engine stderr, malformed responses, CPAL stream errors, and nonzero exits are surfaced in the overlay while the visual model remains fully usable. A CPAL stream error is fatal to that engine instance so an unusable process cannot remain marked as the active owner of audio.

On exit, the adapter clears readiness and queued startup commands. Discarding the queue is important: commands describe momentary physical state and timed auditions, so replaying them during a later launch could produce notes the user no longer holds. The next keyboard transition sends the complete current held-note set, and the next inversion action sends a complete new audition; either is sufficient to reconstruct valid audio state.

No timer, recursive exit handler, or supervisor restarts the engine. A later user audio action may start one replacement process, but an idle failed plugin starts none. Repeated startup failures consequently require repeated user actions and cannot become an automatic crash loop. This bounds process creation, keeps the failure visible, and preserves silent use of the chord visualization.

## Audio/UI integration

- An inversion audition sends exactly one `audition` command for the current UI revision.
- The visible sounding state follows the last acknowledged revision, not merely the last requested revision.
- Audio failure must not prevent silent chord exploration.
- Commands issued during startup queue until the ready event.
- The UI exposes compact engine status and errors.

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
- Broken pipe, engine exit, lazy restart, and graceful shutdown.
- No orphan engine process after plugin unload.

## Acceptance criteria

- A held chord remains stable for at least ten minutes without periodic restart, dropout, or accumulated drift.
- A triad begins as one synchronized engine update.
- Common tones remain continuous when changing between related chords.
- Added and removed notes transition without audible clicks or screeching.
- Twelve active pitch classes do not clip under the default gain policy.
- Rapid UI changes do not create overlapping synth processes or streams.
- Only one synth worker and one audio stream exist during normal operation.
- Killing the engine produces a visible error and the next audio action can start one replacement process.

## Milestone dependency and delivery boundary

Milestone 1 defines the musical state and the complete user interaction. Its mock engine contract is the sole integration boundary for Milestone 2. Engine work should not require redesigning node identity, triad construction, or inversion semantics.

Milestone 1 is complete when the overlay is independently useful and validated. Milestone 2 is complete when the native adapter is integrated, the audio lifecycle passes its tests, and sustained chord changes are audibly smooth.

## Deferred design decision

- Whether a future user setting should allow playback to continue after the overlay closes.
