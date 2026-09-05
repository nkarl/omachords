use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use serde::Deserialize;
use serde_json::json;
use std::error::Error;
use std::f32::consts::TAU;
use std::io::{self, BufRead, Write};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

const MIDI_NOTES: usize = 128;
const ATTACK_SECONDS: f32 = 0.010;
const RELEASE_SECONDS: f32 = 0.045;
const MASTER_GAIN: f32 = 0.24;

#[derive(Debug, Deserialize)]
#[serde(tag = "cmd", rename_all = "snake_case")]
enum Command {
    SetHeld {
        revision: u64,
        notes: Vec<u8>,
    },
    Audition {
        revision: u64,
        notes: Vec<u8>,
        #[serde(default = "default_duration_ms")]
        duration_ms: u64,
    },
    Stop {
        revision: u64,
    },
    Shutdown,
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
        config.clone(),
        move |output: &mut [f32], _| {
            let now_ms = started.elapsed().as_millis().min(u64::MAX as u128) as u64;
            synth.render(output, &audio_state, now_ms);
        },
        |error| eprintln!("audio stream error: {error}"),
        None,
    )?;
    stream.play()?;
    emit(json!({"event":"ready","rate":config.sample_rate,"channels":config.channels}));

    for line in io::stdin().lock().lines() {
        let line = match line {
            Ok(value) => value,
            Err(error) => {
                emit(json!({"event":"error","message":error.to_string()}));
                continue;
            }
        };
        let command: Command = match serde_json::from_str(&line) {
            Ok(value) => value,
            Err(error) => {
                emit(json!({"event":"error","message":format!("invalid command: {error}")}));
                continue;
            }
        };
        match command {
            Command::SetHeld { revision, notes } => {
                shared.set_held(&notes);
                emit(json!({"event":"applied","revision":revision}));
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
                shared.set_audition(&notes, until);
                emit(json!({"event":"applied","revision":revision}));
            }
            Command::Stop { revision } => {
                shared.stop();
                emit(json!({"event":"applied","revision":revision}));
            }
            Command::Shutdown => {
                shared.stop();
                emit(json!({"event":"shutdown"}));
                break;
            }
        }
    }
    drop(stream);
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

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
