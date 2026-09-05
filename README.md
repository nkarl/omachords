# Chord Circle

Chord Circle is a large Omarchy Quattro overlay window for constructing and visualizing chords on a circle of fifths.

Milestone 1 is a silent UI prototype presented as a large, centered, keyboard-exclusive window. A clicked root and the selected quality produce a persistent accent-colored triad, with the root distinguished by a white border. Independently, the same two-octave computer-keyboard layout as `max.piano` provides literal piano semantics: each held key adds a momentary white glow and white held-note edges without replacing the selected triad. Repeated octaves share one node. Root, First, and Second are audition buttons that record the corresponding complete chord command for the persistent synth planned in Milestone 2. A dedicated mock adapter implements that future engine boundary without starting an audio process.

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
