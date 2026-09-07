use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use serde::Deserialize;
use serde::de::{self, SeqAccess, Visitor};
use serde_json::json;
use std::error::Error;
use std::f32::consts::TAU;
use std::fmt;
use std::io::{self, BufRead, Write};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

const MIDI_NOTES: usize = 128;
const MAX_COMMAND_BYTES: usize = 4096;
const MAX_COMMAND_NOTES: usize = 128;
const ATTACK_SECONDS: f32 = 0.010;
const RELEASE_SECONDS: f32 = 0.045;
const MASTER_GAIN: f32 = 0.24;

#[derive(Debug, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum Command {
    SetHeld {
        revision: u64,
        notes: Notes,
    },
    Audition {
        revision: u64,
        notes: Notes,
        #[serde(default = "default_duration_ms")]
        duration_ms: u64,
    },
    Stop {
        revision: u64,
    },
    Shutdown,
}

#[derive(Debug)]
struct Notes {
    values: [u8; MAX_COMMAND_NOTES],
    len: usize,
}

impl Notes {
    fn as_slice(&self) -> &[u8] {
        &self.values[..self.len]
    }
}

impl<'de> Deserialize<'de> for Notes {
    fn deserialize<D: serde::Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        struct NotesVisitor;

        impl<'de> Visitor<'de> for NotesVisitor {
            type Value = Notes;

            fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
                write!(formatter, "at most {MAX_COMMAND_NOTES} note entries")
            }

            fn visit_seq<A: SeqAccess<'de>>(self, mut sequence: A) -> Result<Notes, A::Error> {
                let mut notes = Notes {
                    values: [0; MAX_COMMAND_NOTES],
                    len: 0,
                };
                while let Some(note) = sequence.next_element::<u8>()? {
                    if notes.len == MAX_COMMAND_NOTES {
                        return Err(de::Error::custom("notes exceeds 128 entries"));
                    }
                    notes.values[notes.len] = note;
                    notes.len += 1;
                }
                Ok(notes)
            }
        }

        deserializer.deserialize_seq(NotesVisitor)
    }
}

// Keep a fixed buffer and drain oversized input without accumulating its remainder.
// LF and CRLF terminators do not count toward the JSON byte limit.
fn read_command(reader: &mut impl BufRead) -> io::Result<Option<Result<Command, String>>> {
    let mut bytes = [0_u8; MAX_COMMAND_BYTES + 1]; // Allow a trailing CR before LF.
    let mut len = 0;
    let mut oversized = false;
    let newline = loop {
        let available = match reader.fill_buf() {
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            result => result?,
        };
        if available.is_empty() {
            if len == 0 && !oversized {
                return Ok(None);
            }
            break false;
        }
        let end = available.iter().position(|&byte| byte == b'\n');
        let count = end.unwrap_or(available.len());
        if !oversized {
            if count > bytes.len() - len {
                oversized = true;
            } else {
                bytes[len..len + count].copy_from_slice(&available[..count]);
                len += count;
            }
        }
        reader.consume(count + usize::from(end.is_some()));
        if end.is_some() {
            break true;
        }
    };
    if newline && len > 0 && bytes[len - 1] == b'\r' {
        len -= 1;
    }
    if oversized || len > MAX_COMMAND_BYTES {
        return Ok(Some(Err("command exceeds 4096 bytes".into())));
    }
    Ok(Some(
        serde_json::from_slice(&bytes[..len]).map_err(|error| format!("invalid command: {error}")),
    ))
}

fn default_duration_ms() -> u64 {
    900
}

#[derive(Default)]
struct SharedState {
    held_low: AtomicU64,
    held_high: AtomicU64,
    audition_low: AtomicU64,
    audition_high: AtomicU64,
    audition_until_ms: AtomicU64,
}

impl SharedState {
    fn set_held(&self, notes: &[u8]) {
        let (low, high) = note_bits(notes);
        self.held_low.store(low, Ordering::Release);
        self.held_high.store(high, Ordering::Release);
    }

    fn set_audition(&self, notes: &[u8], until_ms: u64) {
        let (low, high) = note_bits(notes);
        self.audition_low.store(low, Ordering::Release);
        self.audition_high.store(high, Ordering::Release);
        self.audition_until_ms.store(until_ms, Ordering::Release);
    }

    fn stop(&self) {
        self.set_held(&[]);
        self.set_audition(&[], 0);
    }

    fn desired(&self, midi: usize, now_ms: u64) -> bool {
        let held = bit_is_set(
            self.held_low.load(Ordering::Acquire),
            self.held_high.load(Ordering::Acquire),
            midi,
        );
        let audition = now_ms < self.audition_until_ms.load(Ordering::Acquire)
            && bit_is_set(
                self.audition_low.load(Ordering::Acquire),
                self.audition_high.load(Ordering::Acquire),
                midi,
            );
        held || audition
    }
}

#[derive(Clone, Copy)]
struct Voice {
    phase: f32,
    level: f32,
}

impl Default for Voice {
    fn default() -> Self {
        Self {
            phase: 0.0,
            level: 0.0,
        }
    }
}

struct Synth {
    voices: [Voice; MIDI_NOTES],
    sample_rate: f32,
    channels: usize,
}

impl Synth {
    fn new(sample_rate: u32, channels: usize) -> Self {
        Self {
            voices: [Voice::default(); MIDI_NOTES],
            sample_rate: sample_rate as f32,
            channels,
        }
    }

    fn render(&mut self, output: &mut [f32], shared: &SharedState, now_ms: u64) {
        let desired: [bool; MIDI_NOTES] = std::array::from_fn(|midi| shared.desired(midi, now_ms));
        let sounding_count = self
            .voices
            .iter()
            .enumerate()
            .filter(|(midi, voice)| desired[*midi] || voice.level > 0.0)
            .count()
            .max(1) as f32;
        let gain = MASTER_GAIN / sounding_count.sqrt();
        let attack_step = 1.0 / (ATTACK_SECONDS * self.sample_rate);
        let release_step = 1.0 / (RELEASE_SECONDS * self.sample_rate);

        for frame in output.chunks_mut(self.channels) {
            let mut mixed = 0.0;
            for (midi, voice) in self.voices.iter_mut().enumerate() {
                if desired[midi] {
                    voice.level = (voice.level + attack_step).min(1.0);
                } else {
                    voice.level = (voice.level - release_step).max(0.0);
                }
                if voice.level <= 0.0 {
                    continue;
                }

                let tone = (voice.phase.sin()
                    + 0.18 * (voice.phase * 2.0).sin()
                    + 0.08 * (voice.phase * 3.0).sin())
                    / 1.26;
                mixed += tone * voice.level;
                voice.phase =
                    (voice.phase + TAU * midi_frequency(midi as u8) / self.sample_rate) % TAU;
            }
            let sample = (mixed * gain).clamp(-0.95, 0.95);
            frame.fill(sample);
        }
    }
}

fn note_bits(notes: &[u8]) -> (u64, u64) {
    let mut low = 0_u64;
    let mut high = 0_u64;
    for &note in notes {
        if note < 64 {
            low |= 1_u64 << note;
        } else if note < 128 {
            high |= 1_u64 << (note - 64);
        }
    }
    (low, high)
}

fn bit_is_set(low: u64, high: u64, midi: usize) -> bool {
    if midi < 64 {
        low & (1_u64 << midi) != 0
    } else if midi < 128 {
        high & (1_u64 << (midi - 64)) != 0
    } else {
        false
    }
}

fn midi_frequency(note: u8) -> f32 {
    440.0 * 2.0_f32.powf((note as f32 - 69.0) / 12.0)
}

fn emit(value: serde_json::Value) {
    let mut stdout = io::stdout().lock();
    let _ = writeln!(stdout, "{value}");
    let _ = stdout.flush();
}

fn main() -> Result<(), Box<dyn Error>> {
    let host = cpal::default_host();
    let device = host
        .default_output_device()
        .ok_or("no default audio output device")?;
    let supported = device
        .supported_output_configs()?
        .find(|range| range.sample_format() == cpal::SampleFormat::F32)
        .ok_or("the default output device does not support f32 audio")?;
    let preferred_rate = 48_000;
    let sample_rate = if supported.min_sample_rate() <= preferred_rate
        && preferred_rate <= supported.max_sample_rate()
    {
        preferred_rate
    } else {
        supported.max_sample_rate()
    };
    let config = supported.with_sample_rate(sample_rate).config();
    let channels = config.channels as usize;
    let shared = Arc::new(SharedState::default());
    let audio_state = Arc::clone(&shared);
    let started = Instant::now();
    let mut synth = Synth::new(config.sample_rate, channels);

    let stream = device.build_output_stream(
        config,
        move |output: &mut [f32], _| {
            let now_ms = started.elapsed().as_millis().min(u64::MAX as u128) as u64;
            synth.render(output, &audio_state, now_ms);
        },
        |error| {
            eprintln!("audio stream error: {error}");
            std::process::exit(1);
        },
        None,
    )?;
    stream.play()?;
    emit(json!({"event":"ready","rate":config.sample_rate,"channels":config.channels}));

    run_commands(&mut io::stdin().lock(), &shared, started, emit)?;
    drop(stream);
    Ok(())
}

fn run_commands(
    reader: &mut impl BufRead,
    shared: &SharedState,
    started: Instant,
    mut respond: impl FnMut(serde_json::Value),
) -> io::Result<()> {
    while let Some(command) = read_command(reader)? {
        let command = match command {
            Ok(value) => value,
            Err(error) => {
                respond(json!({"event":"error","message":error}));
                continue;
            }
        };
        match command {
            Command::SetHeld { revision, notes } => {
                shared.set_held(notes.as_slice());
                respond(json!({"event":"applied","revision":revision}));
            }
            Command::Audition {
                revision,
                notes,
                duration_ms,
            } => {
                let until = started
                    .elapsed()
                    .checked_add(Duration::from_millis(duration_ms.clamp(50, 10_000)))
                    .unwrap_or_default()
                    .as_millis()
                    .min(u64::MAX as u128) as u64;
                shared.set_audition(notes.as_slice(), until);
                respond(json!({"event":"applied","revision":revision}));
            }
            Command::Stop { revision } => {
                shared.stop();
                respond(json!({"event":"applied","revision":revision}));
            }
            Command::Shutdown => {
                shared.stop();
                respond(json!({"event":"shutdown"}));
                break;
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{BufReader, Cursor, Read};

    #[test]
    fn command_byte_limit_accepts_exact_boundary_and_line_terminators() {
        let command = r#"{"cmd":"stop","revision":1}"#;
        for ending in ["\n", "\r\n", ""] {
            let input = format!(
                "{command}{}{ending}",
                " ".repeat(MAX_COMMAND_BYTES - command.len())
            );
            for capacity in [1, 31, 8192] {
                let mut reader = BufReader::with_capacity(capacity, input.as_bytes());
                assert!(matches!(
                    read_command(&mut reader).unwrap().unwrap().unwrap(),
                    Command::Stop { revision: 1 }
                ));
                assert!(read_command(&mut reader).unwrap().is_none());
            }
        }
    }

    #[test]
    fn oversized_lines_are_drained_and_the_next_command_survives() {
        for size in [MAX_COMMAND_BYTES + 1, 1_000_000] {
            for ending in ["\n", "\r\n"] {
                let input = format!(
                    "{}{ending}{{\"cmd\":\"stop\",\"revision\":2}}\n",
                    "x".repeat(size)
                );
                let mut reader = BufReader::with_capacity(31, input.as_bytes());
                assert_eq!(
                    read_command(&mut reader).unwrap().unwrap().unwrap_err(),
                    "command exceeds 4096 bytes"
                );
                assert!(matches!(
                    read_command(&mut reader).unwrap().unwrap().unwrap(),
                    Command::Stop { revision: 2 }
                ));
                assert!(read_command(&mut reader).unwrap().is_none());
            }
        }
    }

    #[test]
    fn oversized_unterminated_input_uses_a_stream_and_reaches_eof() {
        let input = io::repeat(b'x').take(1_000_000);
        let mut reader = BufReader::with_capacity(64, input);
        assert!(read_command(&mut reader).unwrap().unwrap().is_err());
        assert!(read_command(&mut reader).unwrap().is_none());
    }

    #[test]
    fn byte_limit_counts_utf8_bytes_and_invalid_input_recovers() {
        let input = format!(
            "{{\"cmd\":\"stop\",\"revision\":1,\"extra\":\"{}\"}}\n",
            "é".repeat(2050)
        );
        assert!(input.chars().count() < MAX_COMMAND_BYTES);
        assert_eq!(
            read_command(&mut input.as_bytes())
                .unwrap()
                .unwrap()
                .unwrap_err(),
            "command exceeds 4096 bytes"
        );
        let mut reader = Cursor::new(b"\xff\n\n{bad json}\n{\"cmd\":\"shutdown\"}");
        for _ in 0..3 {
            assert!(read_command(&mut reader).unwrap().unwrap().is_err());
        }
        assert!(matches!(
            read_command(&mut reader).unwrap().unwrap().unwrap(),
            Command::Shutdown
        ));
    }

    #[test]
    fn both_note_commands_accept_128_entries_and_reject_the_129th() {
        for name in ["set_held", "audition"] {
            for count in [0, MAX_COMMAND_NOTES, MAX_COMMAND_NOTES + 1] {
                let input = json!({"cmd":name,"revision":1,"notes":vec![60; count]}).to_string();
                let command = read_command(&mut input.as_bytes()).unwrap().unwrap();
                if count > MAX_COMMAND_NOTES {
                    assert!(command.unwrap_err().contains("notes exceeds 128 entries"));
                } else {
                    let notes = match command.unwrap() {
                        Command::SetHeld { notes, .. } | Command::Audition { notes, .. } => notes,
                        _ => panic!("unexpected command"),
                    };
                    assert_eq!(notes.as_slice(), vec![60; count]);
                }
            }
        }
    }

    #[test]
    fn rejected_commands_preserve_playback_and_a_following_stop_still_works() {
        let state = SharedState::default();
        state.set_held(&[60]);
        state.set_audition(&[64], u64::MAX);
        let too_many = json!({"cmd":"set_held","revision":2,"notes":vec![67; 129]});
        let oversized = format!(
            "{{\"cmd\":\"stop\",\"revision\":3}}{}",
            " ".repeat(MAX_COMMAND_BYTES)
        );
        let input = format!("{too_many}\n{oversized}\n{{\"cmd\":\"stop\",\"revision\":4}}\n");
        let mut responses = Vec::new();
        run_commands(&mut input.as_bytes(), &state, Instant::now(), |response| {
            if response["event"] == "error" {
                assert!(state.desired(60, 0));
                assert!(state.desired(64, 0));
                assert!(!state.desired(67, 0));
            }
            responses.push(response);
        })
        .unwrap();
        assert_eq!(responses.len(), 3);
        assert_eq!(responses[0]["event"], "error");
        assert_eq!(responses[1]["event"], "error");
        assert_eq!(responses[2], json!({"event":"applied","revision":4}));
        assert!(!state.desired(60, 0));
        assert!(!state.desired(64, 0));
    }

    #[test]
    fn midi_a4_is_440_hz() {
        assert!((midi_frequency(69) - 440.0).abs() < 0.001);
    }

    #[test]
    fn note_bits_cover_both_halves_and_deduplicate() {
        let (low, high) = note_bits(&[0, 60, 64, 127, 64]);
        assert!(bit_is_set(low, high, 0));
        assert!(bit_is_set(low, high, 60));
        assert!(bit_is_set(low, high, 64));
        assert!(bit_is_set(low, high, 127));
        assert!(!bit_is_set(low, high, 63));
    }

    #[test]
    fn held_and_audition_sources_are_independent() {
        let state = SharedState::default();
        state.set_held(&[60]);
        state.set_audition(&[64, 67], 1000);
        assert!(state.desired(60, 500));
        assert!(state.desired(64, 500));
        assert!(!state.desired(64, 1000));
        assert!(state.desired(60, 1000));
    }

    #[test]
    fn envelope_attack_and_release_are_gradual() {
        let state = SharedState::default();
        let mut synth = Synth::new(48_000, 2);
        let mut buffer = [0.0_f32; 256];
        state.set_held(&[69]);
        synth.render(&mut buffer, &state, 0);
        let attacked = synth.voices[69].level;
        assert!(attacked > 0.0 && attacked < 1.0);
        state.set_held(&[]);
        synth.render(&mut buffer, &state, 1);
        assert!(synth.voices[69].level < attacked);
        assert!(synth.voices[69].level > 0.0);
    }
}
