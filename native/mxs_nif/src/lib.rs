//! mx's NIF onto mxs: it turns Elixir terms into the engine's types and calls its public API.

mod align;
mod analysis;
mod levels;
mod spectrogram;

use mxs::graph::{Clause, Graph};
use mxs::{BANDS, Effect, Engine, Event, Kind, Levels, Pass, Report, Source, Spec, Synth, Target, Tempo, Topic, Value, effects, synths};
use rustler::types::tuple::get_tuple;
use rustler::{Atom, Binary, Encoder, Env, LocalPid, NifResult, OwnedBinary, OwnedEnv, ResourceArc, Term};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};

rustler::atoms! { ok, error, note, held, release, sample, input, set, stop, sounds, part, effect, send, option, name, list, call, mxs_report, clock, output, voices, levels, pass_ending, pass_started }

struct EngineResource {
    engine: Mutex<Engine>,
}

#[rustler::resource_impl]
impl rustler::Resource for EngineResource {}

type Options = Vec<(String, Value)>;

/// An option's declaration, as a map Elixir reads; an open end of its range is nil, as Erlang has no infinite floats.
#[derive(rustler::NifMap)]
struct SpecTerm {
    name: String,
    kind: String,
    values: Vec<String>,
    default: Option<f64>,
    default_name: Option<String>,
    low: Option<f64>,
    high: Option<f64>,
    required: bool,
    doc: String,
}

/// `:ok`, or `{:error, message}`.
fn reply<'a>(env: Env<'a>, result: Result<(), mxs::Error>) -> Term<'a> {
    match result {
        Ok(()) => ok().encode(env),
        Err(e) => (error(), e.to_string()).encode(env),
    }
}

fn engine() -> Engine {
    let mut engine = Engine::offline(mxs::RATE);
    register(&mut engine);
    engine
}

fn register(engine: &mut Engine) {
    synths::all().into_iter().for_each(|s| engine.register(s));
    effects::all().into_iter().for_each(|e| engine.register_effect(e));
}

fn lock(resource: &ResourceArc<EngineResource>) -> std::sync::MutexGuard<'_, Engine> {
    resource.engine.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

#[rustler::nif(schedule = "DirtyIo")]
fn start(live: bool, with_input: bool) -> Result<ResourceArc<EngineResource>, String> {
    let mut engine = match (live, with_input) {
        (true, true) => Engine::live_with_input().map_err(|e| e.to_string())?,
        (true, false) => Engine::live().map_err(|e| e.to_string())?,
        (false, _) => Engine::offline(mxs::RATE),
    };
    register(&mut engine);
    Ok(ResourceArc::new(EngineResource { engine: Mutex::new(engine) }))
}

/// Starts a live engine on the devices named, at the rate and buffer size given, each nil for the device's default.
#[rustler::nif(schedule = "DirtyIo")]
fn start_with(with_input: bool, settings: (Option<String>, Option<String>, Option<u32>, Option<u32>)) -> Result<ResourceArc<EngineResource>, String> {
    let (device, input_device, rate, buffer) = settings;
    let settings = mxs::Settings { device, with_input, input_device, rate, buffer };
    let mut engine = Engine::live_with(&settings).map_err(|e| e.to_string())?;
    register(&mut engine);
    Ok(ResourceArc::new(EngineResource { engine: Mutex::new(engine) }))
}

/// Each output and input device as `{name, output, default, channels, rates, buffers}`, with `rates` as lowest and highest pairs and `buffers` nil when the device does not say.
#[rustler::nif(schedule = "DirtyIo")]
#[allow(clippy::type_complexity)]
fn devices() -> Result<Vec<(String, bool, bool, Vec<u16>, Vec<(u32, u32)>, Option<(u32, u32)>)>, String> {
    use cpal::traits::{DeviceTrait, HostTrait};
    let host = cpal::default_host();
    let default_name = |device: Option<cpal::Device>| device.and_then(|d| d.description().ok()).map(|d| d.name().to_string());
    let default_output = default_name(host.default_output_device());
    let default_input = default_name(host.default_input_device());
    let devices = mxs::devices().map_err(|e| e.to_string())?;
    Ok(devices
        .into_iter()
        .map(|d| {
            let default = if d.output { &default_output } else { &default_input };
            let is_default = default.as_deref() == Some(d.name.as_str());
            (d.name, d.output, is_default, d.channels, d.rates, d.buffers)
        })
        .collect())
}

/// Each synth's family, such as `winds`, and the lowest and highest notes it is meant to play, or nil when it has no range, as `{name, family, range}`.
#[rustler::nif]
fn families() -> Vec<(String, String, Option<(f64, f64)>)> {
    engine().synths().map(|s| (s.name().to_string(), s.family().name().replace(' ', "_"), s.range())).collect()
}

/// Every synth's options, and those every note, sample, effect and live input takes, as `{synths, note, sample, effects, effect, input}`.
#[rustler::nif]
#[allow(clippy::type_complexity)]
fn catalog() -> (Vec<(String, Vec<SpecTerm>)>, Vec<SpecTerm>, Vec<SpecTerm>, Vec<(String, Vec<SpecTerm>)>, Vec<SpecTerm>, Vec<SpecTerm>) {
    let engine = engine();
    let synths = engine.synths().map(|s| (s.name().to_string(), s.specs().iter().map(spec_term).collect())).collect();
    let effects = engine.effects().map(|e| (e.name().to_string(), e.specs().iter().map(spec_term).collect())).collect();
    let terms = |specs: Vec<Spec>| specs.iter().map(spec_term).collect();
    (synths, terms(engine.note_specs()), terms(engine.sample_specs()), effects, terms(engine.effect_specs()), terms(engine.input_specs()))
}

/// The seconds each of `effects`, as `start_effects` takes them, sounds on after its input stops, with the options declared in beats in beats at `bpm` when given.
#[rustler::nif]
fn effect_tails(effects: Vec<(String, Term)>, bpm: Option<f64>) -> NifResult<Result<Vec<f64>, String>> {
    let effects = effects.into_iter().map(|(name, opts)| Ok((name, options(opts)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(engine().effect_tails(&effects, bpm).map_err(|e| e.to_string()))
}

fn spec_term(spec: &Spec) -> SpecTerm {
    let (kind, values) = match &spec.kind {
        Kind::Note => ("note", vec![]),
        Kind::Hz => ("hz", vec![]),
        Kind::Db => ("db", vec![]),
        Kind::Seconds => ("seconds", vec![]),
        Kind::Ms => ("ms", vec![]),
        Kind::Beats => ("beats", vec![]),
        Kind::Float => ("float", vec![]),
        Kind::Integer => ("integer", vec![]),
        Kind::Boolean => ("boolean", vec![]),
        Kind::Name(values) => ("name", values.clone()),
    };
    let (number, name) = match &spec.default {
        Some(Value::Number(x)) => (Some(*x), None),
        Some(Value::Name(n)) => (None, Some(n.clone())),
        None => (None, None),
    };
    let finite = |x: f64| Some(x).filter(|x| x.is_finite());
    let (low, high) = spec.range.map_or((None, None), |(low, high)| (finite(low), finite(high)));
    SpecTerm {
        name: spec.name.clone(),
        kind: kind.to_string(),
        values,
        default: number,
        default_name: name,
        low,
        high,
        required: spec.required,
        doc: spec.doc.clone(),
    }
}

/// The seconds the engine has played so far.
#[rustler::nif]
fn now(resource: ResourceArc<EngineResource>) -> f64 {
    lock(&resource).now()
}

/// The engine's seconds at which it renders the Unix time `unix_us`, in microseconds, or nil for an offline engine.
#[rustler::nif]
fn seconds_at(resource: ResourceArc<EngineResource>, unix_us: i64) -> Option<f64> {
    let at = std::time::SystemTime::UNIX_EPOCH + std::time::Duration::from_micros(unix_us.max(0) as u64);
    lock(&resource).seconds_at(at)
}

#[rustler::nif]
fn rate(resource: ResourceArc<EngineResource>) -> f64 {
    lock(&resource).rate()
}

/// The rate an offline engine renders at, in Hz.
#[rustler::nif]
fn offline_rate() -> u32 {
    mxs::RATE as u32
}

/// How many channels of the sound card's input the engine reads.
#[rustler::nif]
fn inputs(resource: ResourceArc<EngineResource>) -> usize {
    lock(&resource).inputs()
}

/// Plays `{seconds, event}` pairs, each event `{:note, id, synth, options, chain}`, `{:held, id, synth, options, chain}`, `{:sample, id, sample, options, chain}`, `{:input, id, input, channels, options, chain}`, `{:set, target, options}`, `{:release, ids}` or `{:stop, ids}`.
#[rustler::nif(schedule = "DirtyCpu")]
fn play<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, events: Vec<(f64, Term<'a>)>) -> NifResult<Term<'a>> {
    let events = events.into_iter().map(|(at, term)| Ok((at, event(term)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(reply(env, lock(&resource).play(&events)))
}

/// Plays events, all at the Unix time `unix_us` in microseconds, and returns the reply with the warnings since the last call, waiting for the engine once.
/// An offline engine has no Unix time, and plays them `unix_us` less `origin_us` into its own seconds.
// Building a note's voice takes about a millisecond, more than a NIF may hold a normal scheduler for.
#[rustler::nif(schedule = "DirtyCpu")]
fn play_at<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, unix_us: i64, origin_us: i64, events: Vec<Term<'a>>) -> NifResult<Term<'a>> {
    let events = events.into_iter().map(event).collect::<NifResult<Vec<_>>>()?;
    let mut engine = lock(&resource);
    let at = std::time::SystemTime::UNIX_EPOCH + std::time::Duration::from_micros(unix_us.max(0) as u64);
    let seconds = engine.seconds_at(at).unwrap_or((unix_us - origin_us) as f64 / 1_000_000.0);
    let timed: Vec<(f64, Event)> = events.into_iter().map(|event| (seconds, event)).collect();
    let result = engine.play(&timed);
    let warnings = engine.warnings();
    Ok((reply(env, result), warnings).encode(env))
}

fn event(term: Term) -> NifResult<Event> {
    let parts = get_tuple(term)?;
    let tag: Atom = parts[0].decode()?;
    if (tag == note() || tag == held()) && parts.len() == 5 {
        Ok(Event::Note {
            id: parts[1].decode()?,
            synth: parts[2].decode()?,
            options: options(parts[3])?,
            chain: parts[4].decode()?,
            held: tag == held(),
        })
    } else if tag == sample() && parts.len() == 5 {
        Ok(Event::Sample {
            id: parts[1].decode()?,
            sample: parts[2].decode()?,
            options: options(parts[3])?,
            chain: parts[4].decode()?,
        })
    } else if tag == input() && parts.len() == 6 {
        Ok(Event::Input {
            id: parts[1].decode()?,
            input: parts[2].decode()?,
            channels: parts[3].decode()?,
            options: options(parts[4])?,
            chain: parts[5].decode()?,
        })
    } else if tag == stop() && parts.len() == 2 {
        Ok(Event::Stop { ids: parts[1].decode()? })
    } else if tag == release() && parts.len() == 2 {
        Ok(Event::Release { ids: parts[1].decode()? })
    } else if tag == set() && parts.len() == 3 {
        let options: Vec<(String, f64)> = parts[2].decode()?;
        Ok(Event::Set { target: target(parts[1])?, options })
    } else {
        Err(rustler::Error::BadArg)
    }
}

fn target(term: Term) -> NifResult<Target> {
    let parts = get_tuple(term)?;
    let tag: Atom = parts[0].decode()?;
    if tag == sounds() {
        Ok(Target::Sounds(parts[1].decode()?))
    } else if tag == part() {
        Ok(Target::Part(parts[1].decode()?))
    } else if tag == effect() {
        Ok(Target::Effect(parts[1].decode()?, parts[2].decode()?))
    } else if tag == send() {
        Ok(Target::Send(parts[1].decode()?, parts[2].decode()?))
    } else {
        Err(rustler::Error::BadArg)
    }
}

/// Options as `{name, value}`, each value a float or a name as a string.
/// Registers a synth traced by defsynth: its options' declarations, and each clause as the options it matches and its graph.
#[rustler::nif]
fn register_graph<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, name: String, specs: Vec<SpecTerm>, clauses: Vec<(Term<'a>, Term<'a>)>) -> NifResult<Term<'a>> {
    let specs = specs.into_iter().map(spec).collect();
    let clauses = clauses.into_iter().map(|(matches, graph)| Ok(Clause { matches: options(matches)?, graph: graph_of(graph)? })).collect::<NifResult<_>>()?;
    match Synth::graph(&name, specs, clauses) {
        Ok(synth) => {
            lock(&resource).register(synth);
            Ok(ok().encode(env))
        }
        Err(reason) => Ok((error(), reason).encode(env)),
    }
}

/// Registers an effect traced by defeffect: its options' declarations, and the graph of one channel.
#[rustler::nif]
fn register_effect_graph<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, name: String, specs: Vec<SpecTerm>, graph: Term<'a>) -> NifResult<Term<'a>> {
    let specs = specs.into_iter().map(spec).collect();
    match Effect::graph(&name, specs, graph_of(graph)?) {
        Ok(effect) => {
            lock(&resource).register_effect(effect);
            Ok(ok().encode(env))
        }
        Err(reason) => Ok((error(), reason).encode(env)),
    }
}

fn spec(term: SpecTerm) -> Spec {
    let kind = match term.kind.as_str() {
        "note" => Kind::Note,
        "hz" => Kind::Hz,
        "db" => Kind::Db,
        "seconds" => Kind::Seconds,
        "ms" => Kind::Ms,
        "beats" => Kind::Beats,
        "integer" => Kind::Integer,
        "boolean" => Kind::Boolean,
        "name" => Kind::Name(term.values),
        _ => Kind::Float,
    };
    let mut spec = Spec::new(&term.name, kind).doc(&term.doc);
    if let Some(x) = term.default {
        spec = spec.default(x);
    }
    if let Some(n) = &term.default_name {
        spec = spec.default(n.as_str());
    }
    if term.low.is_some() || term.high.is_some() {
        spec = spec.range(term.low.unwrap_or(f64::NEG_INFINITY), term.high.unwrap_or(f64::INFINITY));
    }
    if term.required { spec.required() } else { spec }
}

/// A graph as defsynth encodes it: a float, `{:option, name}`, `{:name, name}`, `{:list, items}` or `{:call, name, args, named}`.
fn graph_of(term: Term) -> NifResult<Graph> {
    if let Ok(x) = term.decode::<f64>() {
        return Ok(Graph::Number(x));
    }
    let parts = get_tuple(term)?;
    let tag: Atom = parts.first().ok_or(rustler::Error::BadArg)?.decode()?;
    match parts.as_slice() {
        [_, value] if tag == option() => Ok(Graph::Option(value.decode()?)),
        [_, value] if tag == name() => Ok(Graph::Name(value.decode()?)),
        [_, items] if tag == list() => Ok(Graph::List(items.decode::<Vec<Term>>()?.into_iter().map(graph_of).collect::<NifResult<_>>()?)),
        [_, callee, args, named] if tag == call() => {
            let args = args.decode::<Vec<Term>>()?.into_iter().map(graph_of).collect::<NifResult<_>>()?;
            let named = named.decode::<Vec<(String, Term)>>()?.into_iter().map(|(k, v)| Ok((k, graph_of(v)?))).collect::<NifResult<_>>()?;
            Ok(Graph::Call { name: callee.decode()?, args, named })
        }
        _ => Err(rustler::Error::BadArg),
    }
}

fn options(term: Term) -> NifResult<Options> {
    let pairs: Vec<(String, Term)> = term.decode()?;
    pairs
        .into_iter()
        .map(|(name, value)| match value.decode::<f64>() {
            Ok(x) => Ok((name, Value::Number(x))),
            Err(_) => Ok((name, Value::Name(value.decode()?))),
        })
        .collect()
}

/// Loads a sample, and returns its number and channels.
#[rustler::nif(schedule = "DirtyIo")]
fn load_sample(resource: ResourceArc<EngineResource>, path: String) -> Result<(u64, usize), String> {
    let mut engine = lock(&resource);
    let id = engine.load_sample(&path).map_err(|e| e.to_string())?;
    Ok((id, engine.sample_channels(id).unwrap_or(1)))
}

/// The length in seconds of the file at `path`, reading only its headers, or why mxs cannot play it.
#[rustler::nif(schedule = "DirtyIo")]
fn check_sample(path: String) -> Result<f64, String> {
    mxs::check_sample(std::path::Path::new(&path))
}

/// The loudest sample of the file at `path`, as a level from 0, read from all of it.
#[rustler::nif(schedule = "DirtyCpu")]
fn sample_peak(path: String) -> Result<f64, String> {
    mxs::sample_peak(std::path::Path::new(&path)).map(f64::from)
}

/// The pitch in Hz of each frame of `samples` with pYIN, or nil where it finds the frame unvoiced; frame i is centred on sample `i * hop`.
#[rustler::nif(schedule = "DirtyCpu")]
fn pitches(samples: Vec<f64>, rate: u32, lowest: f64, highest: f64, frame: usize, hop: usize) -> Vec<Option<f64>> {
    let mut executor = pyin::PYINExecutor::new(lowest, highest, rate, frame, None, Some(hop), None);
    let (_, hz, voiced, _) = executor.pyin(&samples, f64::NAN, pyin::Framing::Center(pyin::PadMode::Constant(0.0)));
    hz.into_iter().zip(voiced).map(|(hz, voiced)| voiced.then_some(hz)).collect()
}

/// The spectrogram of a stretch of a recording's data as 480 rows of RGB pixels from the top: the data's `{kind, bits, channels}` as `Mx.Audio` names them, the stretch as `{from, count}` in frames, and the columns as `{width, hop, size}`, each starting `hop` samples after the last and holding `size` samples.
/// `per_second` is the columns a second takes, for a line at each second, or nil for none.
#[rustler::nif(schedule = "DirtyCpu")]
fn spectrogram<'a>(env: Env<'a>, data: Binary, format: (String, usize, usize), rate: f64, stretch: (usize, usize), columns: (usize, f64, usize), per_second: Option<f64>) -> NifResult<Binary<'a>> {
    let (kind, bits, channels) = format;
    let sound = spectrogram::samples(data.as_slice(), &kind, bits, channels, stretch.0, stretch.1).ok_or(rustler::Error::BadArg)?;
    let pixels = spectrogram::draw(&sound, rate, columns.0, columns.1, columns.2, per_second);
    let mut owned = OwnedBinary::new(pixels.len()).expect("memory for the picture");
    owned.as_mut_slice().copy_from_slice(&pixels);
    Ok(owned.release(env))
}

/// The loudest sample of a recording's data in any channel, as a level from 0, and the RMS level of each of `count` equal slices of its channels' average; the data's `{kind, bits, channels}` are as `Mx.Audio` names them.
#[rustler::nif(schedule = "DirtyCpu")]
fn levels(data: Binary, format: (String, usize, usize), count: usize) -> NifResult<(f64, Vec<f64>)> {
    let (kind, bits, channels) = format;
    let values = spectrogram::samples(data.as_slice(), &kind, bits, 1, 0, usize::MAX).ok_or(rustler::Error::BadArg)?;
    let peak = values.iter().fold(0.0f64, |peak, value| peak.max(value.abs()));
    let sound: Vec<f64> = values.chunks_exact(channels.max(1)).map(|frame| frame.iter().sum::<f64>() / channels as f64).collect();
    let step = sound.len() as f64 / count.max(1) as f64;
    let slices = (0..count).map(|index| {
        let slice = &sound[(index as f64 * step) as usize..((index + 1) as f64 * step) as usize];
        (slice.iter().map(|x| x * x).sum::<f64>() / slice.len().max(1) as f64).sqrt()
    });
    Ok((peak, slices.collect()))
}

/// Lines the recording in `data` up against `score`, frames of the energy in each pitch class `hop` seconds apart at the score's tempo, the recording starting within its first `free` seconds; returns `{seconds, costs, levels}`: the second each score frame plays at, the cost there from 0 to 2, and the recording's level in dB every 50 ms.
#[rustler::nif(schedule = "DirtyCpu")]
fn align(data: Binary, format: (String, usize, usize), rate: f64, score: Vec<Vec<f64>>, hop: f64, free: f64) -> NifResult<(Vec<f64>, Vec<f64>, Vec<f64>)> {
    let (kind, bits, channels) = format;
    let values = spectrogram::samples(data.as_slice(), &kind, bits, 1, 0, usize::MAX).ok_or(rustler::Error::BadArg)?;
    let sound: Vec<f64> = values.chunks_exact(channels.max(1)).map(|frame| frame.iter().sum::<f64>() / channels as f64).collect();
    let score: Vec<[f64; 12]> = score
        .iter()
        .map(|counts| {
            let mut frame = [0.0; 12];
            frame.iter_mut().zip(counts).for_each(|(slot, count)| *slot = *count);
            align::unit(&mut frame);
            frame
        })
        .collect();
    let (recording, starts) = align::chroma(&sound, rate, hop);
    let (frames, costs) = align::path(&score, &recording, (free / hop) as usize);
    let second = |frame: f64| {
        let (low, high) = (frame.floor() as usize, (frame.ceil() as usize).min(starts.len() - 1));
        starts[low] + (starts[high] - starts[low]) * (frame - frame.floor())
    };
    let seconds = frames.iter().map(|f| second(*f)).collect();
    Ok((seconds, costs, align::levels(&sound, rate, 0.05)))
}

type PianoParts = (Vec<(u32, f64, f64, f64)>, Vec<(u32, String, f64, f64, f64)>, (f64, f64, f64), Option<(f64, Vec<f64>)>, Vec<String>);

/// What a piano note played with `options` is made of, without playing it, as `{harmonics, partners, thump, knock, warnings}`: each harmonic as `{number, hz, level, fade}`, each partner as `{harmonic, kind, hz, level, fade}`, the thump as `{level, below_hz, seconds}`, the knock as `{level, resonances}` or nil, and a warning for each option held to its range.
#[rustler::nif]
fn piano_parts(options: Vec<(String, f64)>) -> Result<PianoParts, String> {
    let options: Vec<(&str, f64)> = options.iter().map(|(name, x)| (name.as_str(), *x)).collect();
    let (parts, warnings) = mxs::synths::piano_parts(&options).map_err(|e| e.to_string())?;
    let harmonics = parts.harmonics.iter().map(|h| (h.number, h.hz, h.level, h.fade)).collect();
    let partners = parts
        .partners
        .iter()
        .map(|p| {
            let kind = match p.kind {
                mxs::synths::PartnerKind::Slow => "slow",
                mxs::synths::PartnerKind::Twin => "twin",
            };
            (p.harmonic, kind.to_string(), p.hz, p.level, p.fade)
        })
        .collect();
    let thump = (parts.thump.level, parts.thump.below_hz, parts.thump.seconds);
    let knock = parts.knock.map(|k| (k.level, k.resonances));
    Ok((harmonics, partners, thump, knock, warnings))
}

/// A recording's levels over time, `per_second` rows a second, each as `{second, level, bands, brightness}`: the level of the whole sound and of each octave from 20 Hz in dB under the loudest row, and the frequency half its energy lies under; the data's `{kind, bits, channels}` are as `Mx.Audio` names them.
#[rustler::nif(schedule = "DirtyCpu")]
fn level_rows(data: Binary, format: (String, usize, usize), rate: f64, per_second: f64) -> NifResult<Vec<levels::Row>> {
    let (kind, bits, channels) = format;
    let sound = spectrogram::samples(data.as_slice(), &kind, bits, channels, 0, usize::MAX).ok_or(rustler::Error::BadArg)?;
    Ok(levels::rows(&sound, rate, per_second))
}

/// The second each sound in a recording starts and its level in dB under the loudest stroke's, as `{second, level}`; the data's `{kind, bits, channels}` are as `Mx.Audio` names them.
#[rustler::nif(schedule = "DirtyCpu")]
fn strokes(data: Binary, format: (String, usize, usize), rate: f64) -> NifResult<Vec<(f64, f64)>> {
    let (kind, bits, channels) = format;
    let sound = spectrogram::samples(data.as_slice(), &kind, bits, channels, 0, usize::MAX).ok_or(rustler::Error::BadArg)?;
    Ok(levels::strokes(&sound, rate))
}

fn sound(data: &Binary, format: &(String, usize, usize)) -> NifResult<Vec<f64>> {
    let (kind, bits, channels) = format;
    spectrogram::samples(data.as_slice(), kind, *bits, *channels, 0, usize::MAX).ok_or(rustler::Error::BadArg)
}

/// The notes plucked or struck in a recording's data whose first note is `note`, or with `whole`, the data as one note from its first sample, as `Mx.Measure` gives them.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_plucked(data: Binary, format: (String, usize, usize), rate: f64, note: i64, whole: bool) -> NifResult<Vec<analysis::plucked::Note>> {
    let sound = sound(&data, &format)?;
    Ok(if whole { analysis::plucked::note(&sound, rate, note).into_iter().collect() } else { analysis::plucked::notes(&sound, rate, note) })
}

/// The hits in a recording's data, or with `whole`, the data as one hit from its first sample, as `Mx.Measure.Hits` gives them.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_hits(data: Binary, format: (String, usize, usize), rate: f64, note: Option<i64>, partials: Option<usize>, whole: bool) -> NifResult<Vec<analysis::hits::Hit>> {
    let sound = sound(&data, &format)?;
    Ok(if whole { analysis::hits::hit(&sound, rate, note, partials).into_iter().collect() } else { analysis::hits::hits(&sound, rate, note, partials) })
}

/// The held notes in a recording's data whose first note is `note`, or with `whole`, the data as one held note from its first sample, as `Mx.Measure.Held` gives them.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_held(data: Binary, format: (String, usize, usize), rate: f64, note: i64, whole: bool) -> NifResult<Vec<analysis::held::Note>> {
    let sound = sound(&data, &format)?;
    Ok(if whole { analysis::held::note(&sound, rate, note).into_iter().collect() } else { analysis::held::notes(&sound, rate, note) })
}

/// A struck note in a recording's data, partial by partial, as `mix mx.measure` prints it with `--partials`.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_struck(data: Binary, format: (String, usize, usize), rate: f64, note: f64) -> NifResult<analysis::fit::Measured> {
    Ok(analysis::fit::measure(&sound(&data, &format)?, rate, note))
}

/// The spike of mx-00181: mx-00177's notes with known partials measured as damped modes.
#[rustler::nif(schedule = "DirtyCpu")]
fn spike_known_modes(rising: bool) -> Vec<analysis::modes::KnownModes> {
    analysis::modes::known(rising)
}

/// The spike of mx-00181: a recording of a struck note, given as to `fit_struck`, its first `seconds_of_modes` as damped modes beside today's fit.
#[rustler::nif(schedule = "DirtyCpu")]
fn spike_strike_modes(recording: Struck, seconds_of_modes: f64, rising: bool) -> NifResult<analysis::modes::Strike> {
    let ((data, format, rate), within, (note, _velocity, seconds, exact)) = recording;
    Ok(analysis::modes::strike(&span(&data, &format, within)?, rate, note, seconds, exact, seconds_of_modes, rising))
}

/// Notes with known partials of every kind at C2, C4 and C7, each measured as a struck recording is and compared with its truth.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_known() -> Vec<analysis::known::Known> {
    analysis::known::all()
}

/// The notes of a recording's data that holds one of `notes` or a run of them, as `Mx.Fit.Struck` splits them, held notes when `held`.
#[rustler::nif(schedule = "DirtyCpu")]
fn split_struck(data: Binary, format: (String, usize, usize), rate: f64, notes: Vec<i64>, held: bool) -> NifResult<Vec<analysis::runs::Piece>> {
    Ok(analysis::runs::split(&sound(&data, &format)?, rate, &notes, held))
}

/// A recording of a struck note: its data, format and rate; the samples the note spans; and its note, a MIDI number or between them for a pitch given in Hz, its velocity, the seconds fitted, and whether the note's frequency is its pitch exactly.
type Struck<'a> = ((Binary<'a>, (String, usize, usize), f64), (usize, usize), (f64, u8, f64, bool));

/// The samples of a recording's data from `from` to `to`.
fn span(data: &Binary, format: &(String, usize, usize), (from, to): (usize, usize)) -> NifResult<Vec<f64>> {
    let sound = sound(data, format)?;
    Ok(sound[from.min(sound.len())..to.min(sound.len())].to_vec())
}

/// The figures of struck notes fitted partial by partial, as mxs reads them, each under its nearest MIDI note.
#[rustler::nif(schedule = "DirtyCpu")]
fn fit_struck<'a>(env: Env<'a>, recordings: Vec<Struck<'a>>) -> NifResult<Binary<'a>> {
    let sounds = recordings.iter().map(|((data, format, rate), within, (note, velocity, seconds, exact))| Ok((span(data, format, *within)?, *rate, *note, *velocity, *seconds, *exact))).collect::<NifResult<Vec<_>>>()?;
    let fitted = analysis::parallel(&sounds, |(sound, rate, note, velocity, seconds, exact)| (note.round() as u8, *velocity, analysis::fit::fit(sound, *rate, *note, *seconds, *exact).0));
    let bytes = analysis::fit::figures_bytes(&fitted);
    let mut binary = OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Atom("no_memory"))?;
    binary.as_mut_slice().copy_from_slice(&bytes);
    Ok(Binary::from_owned(binary, env))
}

/// How far a render of a struck note is from a recording of it, partial by partial and in ERB bands: the recording as a struck one is given to `fit_struck`, the render as its data, format and rate.
#[rustler::nif(schedule = "DirtyCpu")]
fn check_struck(recording: Struck, rendered: (Binary, (String, usize, usize), f64)) -> NifResult<analysis::fit::Check> {
    let ((data, format, rate), within, (note, _velocity, seconds, exact)) = recording;
    let (theirs, ours) = (span(&data, &format, within)?, sound(&rendered.0, &rendered.1)?);
    Ok(analysis::fit::check(&theirs, rate, &ours, rendered.2, note, seconds, exact))
}

/// How far the fit's own render of a struck note, its figures played with no synth, is from the recording, as `check_struck` compares them: the recording as a struck one is given to `fit_struck`.
#[rustler::nif(schedule = "DirtyCpu")]
fn check_fit_struck(recording: Struck) -> NifResult<analysis::fit::Check> {
    let ((data, format, rate), within, (note, _velocity, seconds, exact)) = recording;
    Ok(analysis::fit::own(&span(&data, &format, within)?, rate, note, seconds, exact))
}

/// One recording of a struck note, given as to `fit_struck`, beside a render of the synth when given and the fit's own render, frame by frame at `times` seconds after the strike.
#[rustler::nif(schedule = "DirtyCpu")]
fn frames_struck(recording: Struck, rendered: Option<(Binary, (String, usize, usize), f64)>, times: Vec<f64>) -> NifResult<analysis::fit::Frames> {
    let ((data, format, rate), within, (note, _velocity, seconds, exact)) = recording;
    let theirs = span(&data, &format, within)?;
    let synth = match &rendered {
        Some((data, packing, rate)) => Some((sound(data, packing)?, *rate)),
        None => None,
    };
    let synth = synth.as_ref().map(|(sound, rate)| (sound.as_slice(), *rate));
    Ok(analysis::fit::frames(&theirs, rate, note, seconds, exact, synth, &times))
}

/// A tour for listening of recordings of struck notes, each given as to `fit_struck`, beside renders given as their data, format and rate, as 32-bit floats at the renders' rate.
#[rustler::nif(schedule = "DirtyCpu")]
fn tour_struck<'a>(env: Env<'a>, pairs: Vec<(Struck<'a>, (Binary<'a>, (String, usize, usize), f64))>) -> NifResult<Binary<'a>> {
    let rate = pairs.first().map_or(48000.0, |(_, (_, _, rate))| *rate);
    let sounds = pairs.iter().map(|(((data, format, recording_rate), within, (_, _, seconds, _)), (rendered, packing, _))| Ok((span(data, format, *within)?, *recording_rate, *seconds, sound(rendered, packing)?))).collect::<NifResult<Vec<_>>>()?;
    let bytes: Vec<u8> = analysis::fit::tour(&sounds, rate).iter().flat_map(|x| (*x as f32).to_le_bytes()).collect();
    let mut binary = OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Atom("no_memory"))?;
    binary.as_mut_slice().copy_from_slice(&bytes);
    Ok(Binary::from_owned(binary, env))
}

/// The figures of held notes fitted partial by partial, as mxs reads them, each recording given as to `fit_struck`, and each note held at one level when `steady`, as `analysis::sustained::fit` does.
#[rustler::nif(schedule = "DirtyCpu")]
fn fit_held<'a>(env: Env<'a>, recordings: Vec<Struck<'a>>, steady: bool) -> NifResult<Binary<'a>> {
    let sounds = recordings.iter().map(|((data, format, rate), within, (note, velocity, seconds, _))| Ok((span(data, format, *within)?, *rate, *note, *velocity, *seconds))).collect::<NifResult<Vec<_>>>()?;
    let fitted = analysis::parallel(&sounds, |(sound, rate, note, velocity, seconds)| (note.round() as u8, *velocity, analysis::sustained::fit(sound, *rate, *note, *seconds, steady).0));
    let bytes = analysis::sustained::figures_bytes(&fitted);
    let mut binary = OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Atom("no_memory"))?;
    binary.as_mut_slice().copy_from_slice(&bytes);
    Ok(Binary::from_owned(binary, env))
}

/// How far a render of a held note is from a recording of it, as `check_struck` takes them.
#[rustler::nif(schedule = "DirtyCpu")]
fn check_held(recording: Struck, rendered: (Binary, (String, usize, usize), f64)) -> NifResult<analysis::fit::Check> {
    let ((data, format, rate), within, (note, _velocity, seconds, _)) = recording;
    let (theirs, ours) = (span(&data, &format, within)?, sound(&rendered.0, &rendered.1)?);
    Ok(analysis::sustained::check(&theirs, rate, &ours, rendered.2, 0, note, seconds))
}

/// How far the fit's own render of a held note is from the recording, as `check_held` compares them.
#[rustler::nif(schedule = "DirtyCpu")]
fn check_fit_held(recording: Struck, steady: bool) -> NifResult<analysis::fit::Check> {
    let ((data, format, rate), within, (note, _velocity, seconds, _)) = recording;
    Ok(analysis::sustained::own(&span(&data, &format, within)?, rate, note, seconds, steady))
}

/// Where a recording of a held note holds from and is let go, in seconds after it starts, and the seconds into its span it starts at.
#[rustler::nif(schedule = "DirtyCpu")]
fn timing_held(recording: Struck) -> NifResult<(f64, f64, f64)> {
    let ((data, format, rate), within, (note, _velocity, seconds, _)) = recording;
    Ok(analysis::sustained::timing(&span(&data, &format, within)?, rate, note, seconds))
}

/// A held note partial by partial, as `mix mx.measure --held --partials` prints it, the recording given as to `fit_struck`.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_held_partials(recording: Struck) -> NifResult<analysis::sustained::Summary> {
    let ((data, format, rate), within, (note, _velocity, seconds, _)) = recording;
    Ok(analysis::sustained::summary(&span(&data, &format, within)?, rate, note, seconds))
}

struct StrokesResource {
    recording: analysis::strokes::Recording,
}

#[rustler::resource_impl]
impl rustler::Resource for StrokesResource {}

/// The strokes of a recording's data, and the recording kept for their tracks, as `Mx.Measure.Strokes` gives them.
#[rustler::nif(schedule = "DirtyCpu")]
fn measure_strokes(data: Binary, format: (String, usize, usize), rate: f64) -> NifResult<(ResourceArc<StrokesResource>, Vec<analysis::strokes::Stroke>)> {
    let recording = analysis::strokes::strokes(sound(&data, &format)?, rate);
    let strokes = recording.strokes.clone();
    Ok((ResourceArc::new(StrokesResource { recording }), strokes))
}

/// The tracks of a recording's stroke at `index`, or nil when it has no pitch.
#[rustler::nif(schedule = "DirtyCpu")]
fn stroke_tracks(resource: ResourceArc<StrokesResource>, index: usize, alone: bool, ignore: Option<(f64, f64)>) -> Option<analysis::strokes::Tracks> {
    resource.recording.tracks(index, alone, ignore)
}

/// The pitch of each 10 ms frame of a hummed recording's data as a fractional MIDI note, or nil where it has none, as `Mx.Hum` follows it.
#[rustler::nif(schedule = "DirtyCpu")]
fn hum_pitches(data: Binary, format: (String, usize, usize), rate: f64) -> NifResult<Vec<Option<f64>>> {
    Ok(analysis::hum::pitches(&sound(&data, &format)?, rate))
}

/// The magnitudes of `size` samples of a recording's data from the frame `from`, through a periodic Hann window, bins 0 to `size / 2 - 1`.
#[rustler::nif(schedule = "DirtyCpu")]
fn spectrum(data: Binary, format: (String, usize, usize), from: usize, size: usize) -> NifResult<Vec<f64>> {
    let sound = sound(&data, &format)?;
    Ok(analysis::Spectra::default().take(&sound, from, size))
}

#[rustler::nif]
fn start_effects(resource: ResourceArc<EngineResource>, effects: Vec<(String, Term)>) -> NifResult<Result<u64, String>> {
    let effects = effects.into_iter().map(|(name, opts)| Ok((name, options(opts)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(lock(&resource).start_effects(&effects).map_err(|e| e.to_string()))
}

#[rustler::nif]
fn stop_effects(env: Env, resource: ResourceArc<EngineResource>, chain: u64, at: f64) -> Term {
    reply(env, lock(&resource).stop_effects(chain, at))
}

/// Starts the part `name` with `effects`, as `start_effects` takes them, and returns the chain notes name to play into it.
/// A part of that name already started is removed first, so its sounds end through it and the name is the new part's.
/// With `in_beats`, the options the effects declare in beats are given in beats, and follow the engine's tempo as it changes.
#[rustler::nif]
fn start_part(resource: ResourceArc<EngineResource>, name: String, effects: Vec<(String, Term)>, in_beats: bool) -> NifResult<Result<u64, String>> {
    let effects = effects.into_iter().map(|(name, opts)| Ok((name, options(opts)?))).collect::<NifResult<Vec<_>>>()?;
    let mut engine = lock(&resource);
    if engine.part(&name).is_ok() {
        let now = engine.now();
        if let Err(e) = engine.stop_part(&name, now) {
            return Ok(Err(e.to_string()));
        }
    }
    let started = if in_beats { engine.start_part_in_beats(&name, &effects) } else { engine.start_part(&name, &effects) };
    Ok(started.map_err(|e| e.to_string()))
}

/// Sends a share of the sound of the chain `from` into the chain `to` at `level`, besides where it already goes; a send already made takes the level.
#[rustler::nif]
fn send_chain(env: Env, resource: ResourceArc<EngineResource>, from: u64, to: u64, level: f64) -> Term {
    reply(env, lock(&resource).send(from, to, level))
}

/// Has the effects of `chain` that read a key, such as the compressor, follow the sound of the chain `by`.
#[rustler::nif]
fn key_chain(env: Env, resource: ResourceArc<EngineResource>, chain: u64, by: u64) -> Term {
    reply(env, lock(&resource).key(chain, Some(by)))
}

/// Starts the main effects, which everything the engine plays goes through after its part, in place of those before, and returns the chain a change names to reach them.
/// With `in_beats`, the options the effects declare in beats are given in beats, and follow the engine's tempo as it changes.
#[rustler::nif]
fn start_main(resource: ResourceArc<EngineResource>, effects: Vec<(String, Term)>, in_beats: bool) -> NifResult<Result<u64, String>> {
    let effects = effects.into_iter().map(|(name, opts)| Ok((name, options(opts)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(lock(&resource).start_main_effects(&effects, in_beats).map_err(|e| e.to_string()))
}

/// Places beat 0 of the engine's tempo map at the Unix time `unix_us` in microseconds, which an offline engine takes as `unix_us` less `origin_us` into its own seconds.
#[rustler::nif]
fn place_beats(env: Env, resource: ResourceArc<EngineResource>, unix_us: i64, origin_us: i64) -> Term {
    let mut engine = lock(&resource);
    let at = SystemTime::UNIX_EPOCH + Duration::from_micros(unix_us.max(0) as u64);
    let seconds = engine.seconds_at(at).unwrap_or((unix_us - origin_us) as f64 / 1_000_000.0);
    reply(env, engine.place_beats(seconds))
}

/// Changes the engine's tempo from `beat` on to `bpm` beats a minute, held, or with `moving` as `{from, over}`, moving evenly from `from` to `bpm` over `over` beats.
#[rustler::nif]
fn set_tempo(env: Env, resource: ResourceArc<EngineResource>, beat: f64, bpm: f64, moving: Option<(f64, f64)>) -> Term {
    let tempo = match moving {
        Some((from, over)) => Tempo::Move { from, to: bpm, over },
        None => Tempo::Hold(bpm),
    };
    reply(env, lock(&resource).set_tempo(beat, tempo))
}

/// The engine's seconds at which `beat` falls, by its tempo map as it is now.
#[rustler::nif]
fn beat_seconds(resource: ResourceArc<EngineResource>, beat: f64) -> f64 {
    lock(&resource).beat_seconds(beat)
}

/// Hands the part `name` a pass from the beat `from` to the beat `to`: `events` as `play_at` takes them, each with its beat, and with the options in beats given in beats.
/// `label` is a number of the caller's, and `notice` the beats before `to` at which a subscriber to `"passes"` is told the pass ends, unless another was handed over by then.
/// Returns the reply with the warnings since the last call.
// Checking a pass builds no voice, but a long pass holds hundreds of events.
#[rustler::nif(schedule = "DirtyCpu")]
fn pass<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, name: String, span: (f64, f64), label: u64, notice: Option<f64>, events: Vec<(f64, Term<'a>)>) -> NifResult<Term<'a>> {
    let events = events.into_iter().map(|(beat, term)| Ok((beat, event(term)?))).collect::<NifResult<Vec<_>>>()?;
    let pass = Pass { from: span.0, to: span.1, label, notice, events };
    let mut engine = lock(&resource);
    let result = engine.pass(&name, &pass);
    let warnings = engine.warnings();
    Ok((reply(env, result), warnings).encode(env))
}

/// Drops every event in beats handed to the part `name` for `beat` or after that has not started.
#[rustler::nif]
fn cut(env: Env, resource: ResourceArc<EngineResource>, name: String, beat: f64) -> Term {
    reply(env, lock(&resource).cut(&name, beat))
}

/// Removes the part `name` at `at` seconds, once its notes and its effects' tails have ended, if `chain` is still what it plays into; a chain another part took the name of is removed alone.
#[rustler::nif]
fn stop_part(env: Env, resource: ResourceArc<EngineResource>, name: String, chain: u64, at: f64) -> Term {
    let mut engine = lock(&resource);
    if engine.part(&name).is_ok_and(|current| current == chain) {
        reply(env, engine.stop_part(&name, at))
    } else {
        reply(env, engine.stop_effects(chain, at))
    }
}

/// Mutes the part `name` now, or lets it be heard again; the sounds handed over before are muted with it.
#[rustler::nif]
fn mute_part(env: Env, resource: ResourceArc<EngineResource>, name: String, muted: bool) -> Term {
    let mut engine = lock(&resource);
    let now = engine.now();
    reply(env, engine.mute(&name, muted, now))
}

/// Solos the part `name` now, or ends its solo: while any part is soloed, only the soloed parts are heard.
#[rustler::nif]
fn solo_part(env: Env, resource: ResourceArc<EngineResource>, name: String, soloed: bool) -> Term {
    let mut engine = lock(&resource);
    let now = engine.now();
    reply(env, engine.solo(&name, soloed, now))
}

/// Renders the next seconds of an offline engine, as the left and right channels in native-endian 32-bit floats.
#[rustler::nif(schedule = "DirtyCpu")]
fn render<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, seconds: f64) -> Result<(Binary<'a>, Binary<'a>), String> {
    let (left, right) = lock(&resource).render(seconds).map_err(|e| e.to_string())?;
    let binary = |frames: Vec<f32>| {
        let mut owned = OwnedBinary::new(frames.len() * 4).expect("memory for the render");
        for (chunk, x) in owned.as_mut_slice().as_chunks_mut::<4>().0.iter_mut().zip(frames) {
            chunk.copy_from_slice(&x.to_ne_bytes());
        }
        owned.release(env)
    };
    Ok((binary(left), binary(right)))
}

/// Records `{:input, number}`, numbered from 0, or `{:sample, sample}` to a WAV file from `at` seconds.
#[rustler::nif(schedule = "DirtyIo")]
fn record<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, path: String, source: Term<'a>, at: f64) -> NifResult<Term<'a>> {
    let (tag, number): (Atom, u64) = source.decode()?;
    let source = if tag == input() {
        Source::Input(number as usize)
    } else if tag == sample() {
        Source::Sample(number)
    } else {
        return Err(rustler::Error::BadArg);
    };
    Ok(reply(env, lock(&resource).record(&path, source, at)))
}

#[rustler::nif(schedule = "DirtyIo")]
fn stop_recording(env: Env, resource: ResourceArc<EngineResource>) -> Term {
    reply(env, lock(&resource).stop_recording())
}

/// Records the main output to a WAV file from `at` seconds.
#[rustler::nif(schedule = "DirtyIo")]
fn record_output(env: Env, resource: ResourceArc<EngineResource>, path: String, at: f64) -> Term {
    reply(env, lock(&resource).record_output(&path, at))
}

#[rustler::nif(schedule = "DirtyIo")]
fn stop_recording_output(env: Env, resource: ResourceArc<EngineResource>) -> Term {
    reply(env, lock(&resource).stop_recording_output())
}

/// Whether any note or sample is still sounding.
#[rustler::nif]
fn sounding(resource: ResourceArc<EngineResource>) -> bool {
    lock(&resource).sounding()
}

#[rustler::nif]
fn warnings(resource: ResourceArc<EngineResource>) -> Vec<String> {
    lock(&resource).warnings()
}

/// How filling audio went since the last call, as `{buffers, mean, worst, late}`: how many buffers were filled, the time filling took as a share of the time they last, over all of them and at worst, and how many of a live engine's reached the sound card late.
#[rustler::nif]
fn buffer_load(resource: ResourceArc<EngineResource>) -> (u64, f64, f64, u64) {
    let load = lock(&resource).load();
    (load.buffers, load.mean, load.worst, load.late)
}

/// A subscription to an engine's reports, which ends once Elixir holds it no longer.
struct SubscriptionResource {
    ended: Arc<AtomicBool>,
}

impl Drop for SubscriptionResource {
    fn drop(&mut self) {
        self.ended.store(true, Ordering::Release);
    }
}

#[rustler::resource_impl]
impl rustler::Resource for SubscriptionResource {}

/// Sends `pid` the engine's reports of the kinds named, `"clock"`, `"output"`, `"voices"`, `"levels"` and `"passes"`, each as `{:mxs_report, report}`, until what it returns is given to `unsubscribe` or collected, or `pid` is gone.
/// A clock report is `{:clock, seconds, unix_us, delay}`: the Unix time in microseconds at which the sound card plays the engine's seconds, and the output's delay in seconds.
/// An output report is `{:output, seconds, device, rate, delay_ms}`, with nil for what the device does not say.
/// A voices report is `{:voices, seconds, sounding}`, the notes that sound, about once a second.
/// A passes report is `{:pass_ending, seconds, part, beat}`, when the part's last pass ends within the notice it was handed with, at `beat`, or `{:pass_started, seconds, part, label, beat}`, when the first event of a pass with another label starts.
/// A levels report is `{:levels, seconds, {peak, rms, full_scale}, wave, bands, parts}`, twenty times a second: the output's peak and RMS level, each as `{left, right}`, whether it reached full scale, its wave as 64 points, its level in dB in each of the bands `level_bands` gives, and each named part as `{name, peak, rms}`.
#[rustler::nif]
fn subscribe(resource: ResourceArc<EngineResource>, pid: LocalPid, kinds: Vec<String>) -> NifResult<ResourceArc<SubscriptionResource>> {
    let topic = |kind: &String| match kind.as_str() {
        "clock" => Ok(Topic::Clock),
        "output" => Ok(Topic::Output),
        "voices" => Ok(Topic::Voices),
        "levels" => Ok(Topic::Levels),
        "passes" => Ok(Topic::Passes),
        _ => Err(rustler::Error::BadArg),
    };
    let topics = kinds.iter().map(topic).collect::<NifResult<Vec<_>>>()?;
    let reports = lock(&resource).subscribe(&topics);
    let ended = Arc::new(AtomicBool::new(false));
    let subscription = SubscriptionResource { ended: ended.clone() };
    let forward = move || {
        let mut env = OwnedEnv::new();
        while !ended.load(Ordering::Acquire) {
            let Some(report) = reports.wait(Duration::from_millis(100)) else { continue };
            let sent = match report {
                Report::Clock { seconds, system, delay } => {
                    let unix_us = system.duration_since(SystemTime::UNIX_EPOCH).unwrap_or_default().as_micros() as i64;
                    env.send_and_clear(&pid, |env| (mxs_report(), (clock(), seconds, unix_us, delay)).encode(env))
                }
                Report::Output { seconds, device, rate, delay_ms } => {
                    env.send_and_clear(&pid, |env| (mxs_report(), (output(), seconds, device, rate, delay_ms)).encode(env))
                }
                Report::Voices { seconds, sounding } => env.send_and_clear(&pid, |env| (mxs_report(), (voices(), seconds, sounding)).encode(env)),
                Report::Levels(report) => {
                    let pair = |[left, right]: [f32; 2]| (left, right);
                    let parts: Vec<_> = report.parts.iter().map(|part| (part.name.clone(), pair(part.peak), pair(part.rms))).collect();
                    env.send_and_clear(&pid, |env| (mxs_report(), (levels(), report.seconds, (pair(report.peak), pair(report.rms), report.full_scale), report.wave.to_vec(), report.bands.to_vec(), parts)).encode(env))
                }
                Report::PassEnding { seconds, part, beat } => env.send_and_clear(&pid, |env| (mxs_report(), (pass_ending(), seconds, part, beat)).encode(env)),
                Report::PassStarted { seconds, part, label, beat } => env.send_and_clear(&pid, |env| (mxs_report(), (pass_started(), seconds, part, label, beat)).encode(env)),
                _ => Ok(()),
            };
            if sent.is_err() {
                break;
            }
        }
    };
    std::thread::Builder::new().name("mxs_nif reports".to_string()).spawn(forward).map_err(|_| rustler::Error::Term(Box::new("no thread for the reports")))?;
    Ok(ResourceArc::new(subscription))
}

/// The lowest and the highest frequency in Hz of each band of a levels report, the lowest band first.
#[rustler::nif]
fn level_bands() -> Vec<(f64, f64)> {
    (0..BANDS).map(Levels::band).collect()
}

/// Ends a subscription now: no report is sent after the one being sent, and the engine stops making the reports no one else asked for.
#[rustler::nif]
fn unsubscribe(subscription: ResourceArc<SubscriptionResource>) -> Atom {
    subscription.ended.store(true, Ordering::Release);
    ok()
}

/// Panics on purpose, so a test can check that a panic raises in Elixir instead of stopping the BEAM.
#[rustler::nif]
fn panic_on_purpose() -> Atom {
    // resume_unwind skips the panic hook, whose stderr output a test cannot capture.
    std::panic::resume_unwind(Box::new("on purpose"))
}

rustler::init!("Elixir.Mx.Engine.Mxs.Native");
