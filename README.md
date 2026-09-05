# Chord Circle

Chord Circle is a large Omarchy Quattro overlay window for constructing and visualizing chords in two coordinated pitch spaces.

Chord Circle is a large, centered, keyboard-exclusive overlay. Its interactive inner circle orders pitch classes by fifths and draws chord graphs in tonal space. Its quieter outer ring orders the same pitch classes chromatically as twelve separated radial beams, revealing semitone distance without adding another graph. Each beam is narrow, extends substantially beyond the tonal circle, and fades from its strongest intensity at the inner edge into the overlay background at its outer end. A pitch selected by the preset or held at the keyboard appears in both spaces. The outer ring mirrors the inner ring's independent layers at lower intensity: preset chord tones use a muted accent shade, held notes receive a temporary white wash and outline, and the preset root keeps a stronger white outline that distinguishes it from the third and fifth.

A clicked root, chord family, and quality produce a persistent accent-colored triad or seventh chord, with the root distinguished by a white border. The Seventh family explicitly supports major seventh, dominant seventh, minor seventh, half-diminished seventh, diminished seventh, augmented major seventh, and minor-major seventh. Independently, up to 31 computer keys provide literal piano semantics: each held key adds a momentary white glow, white held-note edges, and sustained audio without replacing the selected chord. Repeated octaves share one node. Root, First, Second, and—where applicable—Third audition concrete MIDI voicings through one persistent Rust/CPAL audio process.

Triad and Seventh controls switch chord families. Triads provide Major, Minor, Diminished, and Augmented qualities; sevenths provide `maj7`, `7`, `m7`, `m7♭5`, `dim7`, `augMaj7`, and `mMaj7`. Quality remains an optional exclusive selection: clicking the active quality toggles it off, clears the persistent chord while preserving the selected root, and disables inversion auditions until a quality is chosen again.

The center acts as an analytical lens rather than only a chord label. It displays the spelled chord tones, scale-degree roles, and zero-based chromatic coordinates together—for example `A · C · E · G`, `1 · ♭3 · 5 · ♭7`, and `0 · 3 · 7 · 10`. Its semantic rows use fixed-height line boxes with explicit vertical centering so accidental glyphs cannot shift neighboring rows, and the three analytical rows share the same body text size. Active tonal nodes show their role relative to the interpreted root, including seventh roles `7`, `♭7`, and `𝄫7`. When held notes form a recognized triad or seventh chord, their momentary white layer uses that played chord's roles; otherwise the secondary node label remains its computer-key binding. Held pitch classes also produce temporary numerical markers at their chromatic positions inside the tonal circle. These coordinates run clockwise from `0` at C at the top through `11` at B and directly mirror the simultaneously activated outer-ring sectors.

The current range appears as non-interactive status text beside a dedicated gear button, which is the stable entry point for all settings. The settings modal provides lower and upper semitone handles between C2 and C6. A range may contain at most 31 inclusive notes (2.5 octaves); moving a handle beyond that span shifts the opposite bound. The default is C3–C5, and narrower choices simply leave later computer keys unused. Preset auditions use the lowest complete inversion voicing that fits inside the selected range and report when no complete triad fits. The selection is stored with the plugin entry in `~/.config/omarchy/shell.json` and survives shell restarts.

Settings also provides a session-only On-demand Focus toggle. Off retains exclusive keyboard ownership for uninterrupted playing. On uses Wayland on-demand keyboard focus so another window, such as OBS Studio on a second display, can receive focus while Chord Circle remains open. Held computer-key notes are released whenever the on-demand overlay loses focus, preventing stuck audio when release events go to the newly focused application. Closing and reopening Chord Circle always restores Exclusive mode; this temporary recording convenience is never persisted.

The 31 notes map in ascending semitone order to `A W S E D F T G Y H U J K O L P ; ' [ Z ] X \ C V B N M , . /`. Only the first key for each note in the selected range is active.

Every mapping slot can be rebound from the Range settings modal. Select a numbered slot and press its replacement key. Assigning a key that is already used swaps the two slots, preserving a deterministic one-key-to-one-note map. Custom bindings persist with the range settings, while Reset restores the original 31-key layout.

Keyboard input never cycles the root, family, quality, or inversion. Each mapped key always represents one fixed note, and repeatedly playing the same combination yields the same pitch-class set and chord identification. Physical press and release events update the held set exactly once; Qt-marked auto-repeat events and duplicate transitions are ignored.

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
