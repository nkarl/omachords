# Chord Circle

Chord Circle is a large Omarchy Quattro overlay window for constructing and visualizing chords on a circle of fifths.

Chord Circle is a large, centered, keyboard-exclusive overlay. A clicked root and the selected quality produce a persistent accent-colored triad, with the root distinguished by a white border. Independently, the same two-octave computer-keyboard layout as `max.piano` provides literal piano semantics: each held key adds a momentary white glow, white held-note edges, and sustained audio without replacing the selected triad. Repeated octaves share one node. Root, First, and Second audition concrete MIDI voicings through one persistent Rust/CPAL audio process.

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
