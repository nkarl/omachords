# Chord Circle

Chord Circle is a large Omarchy Quattro overlay window for constructing and visualizing chords in two coordinated pitch spaces.

Chord Circle is a large, centered, keyboard-exclusive overlay. Its interactive inner circle orders pitch classes by fifths and draws chord graphs in tonal space. Its quieter outer ring orders the same pitch classes chromatically as twelve separated blocks, revealing semitone distance without adding another graph. A pitch selected by the preset or held at the keyboard appears in both spaces. The outer ring mirrors the inner ring's independent layers at lower intensity: preset chord tones use a muted accent shade, held notes receive a temporary white wash and outline, and the preset root keeps a stronger white outline that distinguishes it from the third and fifth.

A clicked root and the selected quality produce a persistent accent-colored triad, with the root distinguished by a white border. Independently, the same two-octave computer-keyboard layout as `max.piano` provides literal piano semantics: each held key adds a momentary white glow, white held-note edges, and sustained audio without replacing the selected triad. Repeated octaves share one node. Root, First, and Second audition concrete MIDI voicings through one persistent Rust/CPAL audio process.

White notes use `A S D F G H J K L ; ' Z X C V`; black notes use `W E T Y U O P [ ] \`.

Keyboard input never cycles the root, quality, or inversion. Each mapped key always represents one fixed note, and repeatedly playing the same combination yields the same pitch-class set and triad identification. Physical press and release events update the held set exactly once; Qt-marked auto-repeat events and duplicate transitions are ignored.

## Development

```bash
omarchy plugin validate .
node --test tests/model.test.mjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
cargo test --manifest-path engine/Cargo.toml
cargo build --release --manifest-path engine/Cargo.toml
mkdir -p bin
install -m755 engine/target/release/chord-circle-engine bin/chord-circle-engine
qmllint -I /usr/share/omarchy/shell Panel.qml EngineAdapter.qml MockEngine.qml
```

The compiled binary is intentionally ignored by Git. Build and install it into `bin/` before running the plugin.

## Audio engine

The overlay starts `bin/chord-circle-engine` lazily when the first keyboard note or inversion audition requests audio. The Rust process owns one CPAL output stream and 128 fixed MIDI voice slots. Its realtime callback reads atomic held-note and audition-note bitsets, preserves oscillator phase, applies 10 ms attack and 45 ms release envelopes, and mixes a restrained three-harmonic waveform. JSON parsing, allocation, process control, and UI communication remain outside the audio callback.

Keyboard notes and inversion auditions are independent sound sources. `set_held` replaces the complete set of physically held MIDI notes and sustains them indefinitely. `audition` adds a concrete inversion voicing for 900 ms. The callback plays the union, so releasing a keyboard key cannot cancel an active inversion audition. Closing the overlay sends `stop`, which clears both sources while leaving the engine available for the next use.

### Failure and restart policy

Engine failure is deliberately passive and user-driven:

- A startup failure, CPAL stream failure, malformed engine response, stderr diagnostic, or nonzero process exit is shown in the overlay's status line. Visual chord exploration continues because UI state does not depend on audio availability.
- A CPAL runtime stream error terminates the failed engine process. The adapter does not leave a nominally running but unusable process behind.
- When the process exits, the adapter marks it unavailable and discards queued startup commands so a later launch cannot replay stale notes or auditions.
- There is no restart timer, recursive callback, retry counter, or background supervisor. An unchanged failure therefore produces zero additional processes.
- The next physical note transition or inversion-button press may request audio again. That action starts at most one new process and queues its current complete command until the new engine emits `ready`.
- If startup fails repeatedly, each failure requires another explicit user audio action. The plugin never creates a self-sustaining crash loop or process storm.

This policy favors predictable resource use over seamless automatic recovery. It also makes failures observable instead of hiding them behind repeated retries.
