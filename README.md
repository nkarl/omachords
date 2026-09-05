# Omachords

Omachords is an educational chord explorer and playable computer-keyboard instrument for Omarchy Quattro. It presents every pitch class in two coordinated views: an inner circle of fifths for tonal relationships and an outer chromatic ring for semitone distance.

## Features

- Construct major, minor, diminished, and augmented triads.
- Construct major seventh, dominant seventh, minor seventh, half-diminished seventh, diminished seventh, augmented-major seventh, and minor-major seventh chords.
- Audition root position and every available inversion.
- See chord tones as a persistent graph while independently playing momentary notes from the computer keyboard.
- Compare scale-degree roles with zero-based chromatic coordinates in the center lens.
- Choose a playable range of up to 31 notes between C2 and C6 and rebind every mapped key.
- Switch temporarily from exclusive to on-demand keyboard focus when recording or working beside another application.
- Produce sustained, low-latency audio through one persistent Rust/CPAL engine process.

## Requirements

- Omarchy Quattro with `omarchy-shell` plugin support.
- PipeWire, PipeWire's ALSA support, and a working system audio output.
- Rust, Cargo, `alsa-lib`, and `pkgconf` to build the audio engine. Install them on Omarchy with `omarchy pkg add rust alsa-lib pkgconf` if needed.

Omachords runs as unsandboxed user code inside `omarchy-shell`. Review third-party plugin source before enabling it.

## Installation

Install and enable the plugin from its public Git repository:

```bash
omarchy plugin add https://github.com/nkarl/omachords.git --enable
```

Run the setup script. It builds the audio engine, enables the plugin, and configures `Super` + `Shift` + `K` unless that shortcut is already customized:

```bash
~/.config/omarchy/plugins/nkarl.omachords/install.sh
```

Use `install.sh --no-shortcut` to build and enable Omachords without changing Hyprland bindings. The script backs up `bindings.lua` before adding its marked shortcut block. If the shortcut already has a user-defined binding, the script leaves it untouched and prints the direct toggle command instead.

The visualization remains usable if the engine is unavailable. An engine error appears in the overlay, and another audio attempt occurs only after a new note or inversion action; failures never trigger an automatic restart loop.

## Usage

Open or close Omachords directly with:

```bash
omarchy-shell shell toggle nkarl.omachords '{}'
```

The setup script assigns `Super` + `Shift` + `K` by adding the following marked override to `~/.config/hypr/bindings.lua`. It replaces Omarchy's stock action but never replaces another customization detected in that file:

```lua
hl.unbind("SUPER + SHIFT + K")
o.bind("SUPER + SHIFT + K", "Omachords", "omarchy-shell shell toggle nkarl.omachords {}")
```

Reload and check the Hyprland configuration:

```bash
hyprctl reload
hyprctl configerrors
```

- Click an inner-circle note to select the chord root.
- Choose `TRIAD` or `7TH`, then choose a quality to display the persistent chord.
- Select `Root`, `First`, `Second`, or `Third` to audition an inversion when that inversion exists.
- Hold mapped computer keys to play notes independently of the selected chord. Repeated key events are ignored, and releasing a key removes only its momentary note.
- Open Settings with the gear button to adjust the range, rebind keys, or enable session-only on-demand focus.

The default keys ascend chromatically across `A W S E D F T G Y H U J K O L P ; ' [ Z ] X \ C V B N M , . /`. The default range is C3–C5.

## Removal

```bash
~/.config/omarchy/plugins/nkarl.omachords/uninstall.sh
```

The removal script deletes only its marked shortcut block, keeps a backup of `bindings.lua`, validates Hyprland, and then delegates plugin removal to Omarchy.

## Development

Development happens on `work`; `main` is reserved for tested, deployment-ready snapshots.

Run the complete validation suite before promoting a change:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml EngineAdapter.qml MockEngine.qml
node --test tests/model.test.mjs
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests
cargo test --manifest-path engine/Cargo.toml
cargo build --release --manifest-path engine/Cargo.toml
bash -n install.sh uninstall.sh
```

The compiled engine under `bin/` and Cargo build output are intentionally excluded from version control.

## References and prior art

Omachords grew from studying two enabled Omarchy plugins: [`max.piano` (Quick Piano)](https://github.com/JarlMaxi/omarchy-quick-piano) by Max Arvidsson informed its computer-keyboard instrument behavior, while [`io.github.markschellhas.circle-of-fifths` (Circle of Fifths)](https://github.com/markschellhas/omarchy-circle-of-fifths) by Mark Schellhas informed its circular tonal visualization. Omachords combines and extends those interaction ideas with independent preset and held-note layers, coordinated fifths and chromatic spaces, analytical chord coordinates, seventh chords, inversions, configurable mappings, and a persistent Rust/CPAL audio engine.

## License

Omachords is available under the [MIT License](LICENSE).
