//! mx's NIF onto mxs: it turns Elixir terms into the engine's types and calls its public API.

use mxs::graph::{Clause, Graph};
use mxs::{Effect, Engine, Event, Kind, Source, Spec, Synth, Target, Value, effects, synths};
use rustler::types::tuple::get_tuple;
use rustler::{Atom, Binary, Encoder, Env, NifResult, OwnedBinary, ResourceArc, Term};
use std::sync::Mutex;

rustler::atoms! { ok, error, note, sample, input, set, stop, sounds, part, effect, option, name, list, call }

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

/// Every synth's options, and those every note, sample and effect takes, as `{synths, note, sample, effects, effect}`.
#[rustler::nif]
#[allow(clippy::type_complexity)]
fn catalog() -> (Vec<(String, Vec<SpecTerm>)>, Vec<SpecTerm>, Vec<SpecTerm>, Vec<(String, Vec<SpecTerm>)>, Vec<SpecTerm>) {
    let engine = engine();
    let synths = engine.synths().map(|s| (s.name().to_string(), s.specs().iter().map(spec_term).collect())).collect();
    let effects = engine.effects().map(|e| (e.name().to_string(), e.specs().iter().map(spec_term).collect())).collect();
    let terms = |specs: Vec<Spec>| specs.iter().map(spec_term).collect();
    (synths, terms(engine.note_specs()), terms(engine.sample_specs()), effects, terms(engine.effect_specs()))
}

fn spec_term(spec: &Spec) -> SpecTerm {
    let (kind, values) = match &spec.kind {
        Kind::Note => ("note", vec![]),
        Kind::Hz => ("hz", vec![]),
        Kind::Db => ("db", vec![]),
        Kind::Seconds => ("seconds", vec![]),
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

/// How many channels of the sound card's input the engine reads.
#[rustler::nif]
fn inputs(resource: ResourceArc<EngineResource>) -> usize {
    lock(&resource).inputs()
}

/// Plays `{seconds, event}` pairs, each event `{:note, id, synth, options, chain}`, `{:sample, id, sample, options, chain}`, `{:input, id, input, channels, options, chain}`, `{:set, target, options}` or `{:stop, ids}`.
#[rustler::nif]
fn play<'a>(env: Env<'a>, resource: ResourceArc<EngineResource>, events: Vec<(f64, Term<'a>)>) -> NifResult<Term<'a>> {
    let events = events.into_iter().map(|(at, term)| Ok((at, event(term)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(reply(env, lock(&resource).play(&events)))
}

fn event(term: Term) -> NifResult<Event> {
    let parts = get_tuple(term)?;
    let tag: Atom = parts[0].decode()?;
    if tag == note() && parts.len() == 5 {
        Ok(Event::Note {
            id: parts[1].decode()?,
            synth: parts[2].decode()?,
            options: options(parts[3])?,
            chain: parts[4].decode()?,
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

#[rustler::nif]
fn start_effects(resource: ResourceArc<EngineResource>, effects: Vec<(String, Term)>) -> NifResult<Result<u64, String>> {
    let effects = effects.into_iter().map(|(name, opts)| Ok((name, options(opts)?))).collect::<NifResult<Vec<_>>>()?;
    Ok(lock(&resource).start_effects(&effects).map_err(|e| e.to_string()))
}

#[rustler::nif]
fn stop_effects(env: Env, resource: ResourceArc<EngineResource>, chain: u64, at: f64) -> Term {
    reply(env, lock(&resource).stop_effects(chain, at))
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

/// Panics on purpose, so a test can check that a panic raises in Elixir instead of stopping the BEAM.
#[rustler::nif]
fn panic_on_purpose() -> Atom {
    // resume_unwind skips the panic hook, whose stderr output a test cannot capture.
    std::panic::resume_unwind(Box::new("on purpose"))
}

rustler::init!("Elixir.Mx.Engine.Mxs.Native");
