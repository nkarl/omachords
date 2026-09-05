# Chord Circle

Chord Circle is a large Omarchy Quattro overlay window for constructing and visualizing chords on a circle of fifths.

Milestone 1 is a silent UI prototype presented as a large, centered, keyboard-exclusive window. It uses the same two-octave computer-keyboard layout as `max.piano`, with literal piano semantics: each pressed key immediately activates its pitch-class node, held keys combine into edges and shapes, and each released key immediately deactivates only its own note. Repeated octaves share one node. The root, quality, and inversion controls leave keyboard mode and provide triad presets, while Play records the atomic command that the persistent synth will receive in Milestone 2. A dedicated mock adapter implements the future engine boundary without starting an audio process.

White notes use `A S D F G H J K L ; ' Z X C V`; black notes use `W E T Y U O P [ ] \`.

Keyboard input never cycles the root, quality, or inversion. Each mapped key always represents one fixed note, and repeatedly playing the same combination yields the same pitch-class set and triad identification. Physical press and release events update the held set exactly once; Qt-marked auto-repeat events and duplicate transitions are ignored.

## Development

```bash
omarchy plugin validate .
node --test tests/model.test.mjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
qmllint -I /usr/share/omarchy/shell Panel.qml MockEngine.qml
```

The repository is not installed or enabled automatically. Plugin installation and the persistent audio engine are outside Milestone 1.
