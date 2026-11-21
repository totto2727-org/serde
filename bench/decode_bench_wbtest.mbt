///|
priv suberror PatternError {
  Invalid
}

///|
fn decode_pattern(input : Json) -> Request raise {
  guard input
    is {
      "requestId": String(request_id),
      "version": version,
      "user": {
        "name": String(name),
        "active": True
        | False as active,
        "age": age,
        "score": score,
        "metadata": { "tags": Array(tags), .. },
        ..
      },
      "project": { "id": String(id), "archived": True | False as archived, .. },
      "metrics": { "latencyMs": latency_ms, "attempts": attempts, .. },
      "payload": { "title": String(title), .. },
      ..
    } else {
    raise PatternError::Invalid
  }
  let tags = tags.map(tag => {
    guard tag is String(value) else { raise PatternError::Invalid }
    value
  })
  {
    request_id,
    version: @json.from_json(version),
    user: {
      name,
      active: active is True,
      age: @json.from_json(age),
      score: @json.from_json(score),
      metadata: { tags, },
    },
    project: { id, archived: archived is True, },
    metrics: {
      latency_ms: @json.from_json(latency_ms),
      attempts: @json.from_json(attempts),
    },
    payload: { title, },
  }
}

///|
struct RequestLenses {
  request_id : @lens.Lens[String]
  version : @lens.Lens[Int32]
  name : @lens.Lens[String]
  active : @lens.Lens[Bool]
  age : @lens.Lens[Int32]
  score : @lens.Lens[Double]
  tags : @lens.Lens[Array[String]]
  project_id : @lens.Lens[String]
  archived : @lens.Lens[Bool]
  latency_ms : @lens.Lens[Double]
  attempts : @lens.Lens[Int32]
  title : @lens.Lens[String]
}

///|
fn build_lenses() -> RequestLenses {
  let root = @lens.root()
  let user = root.object("user")
  let project = root.object("project")
  let metrics = root.object("metrics")
  {
    request_id: root.string("requestId"),
    version: root.custom("version"),
    name: user.string("name"),
    active: user.bool("active"),
    age: user.custom("age"),
    score: user.custom("score"),
    tags: user.object("metadata").string("tags").array(),
    project_id: project.string("id"),
    archived: project.bool("archived"),
    latency_ms: metrics.custom("latencyMs"),
    attempts: metrics.custom("attempts"),
    title: root.object("payload").string("title"),
  }
}

///|
fn decode_lens(lenses : RequestLenses, input : Json) -> Request raise {
  {
    request_id: lenses.request_id.get(input),
    version: lenses.version.get(input),
    user: {
      name: lenses.name.get(input),
      active: lenses.active.get(input),
      age: lenses.age.get(input),
      score: lenses.score.get(input),
      metadata: { tags: lenses.tags.get(input), },
    },
    project: {
      id: lenses.project_id.get(input),
      archived: lenses.archived.get(input),
    },
    metrics: {
      latency_ms: lenses.latency_ms.get(input),
      attempts: lenses.attempts.get(input),
    },
    payload: { title: lenses.title.get(input), },
  }
}

///|
let prebuilt : RequestLenses = build_lenses()

///|
let decoders : ReadOnlyArray[(String, (Json) -> Request raise)] = [
  ("pattern", decode_pattern),
  ("lens-per-call", input => decode_lens(build_lenses(), input)),
  ("lens-prebuilt", input => decode_lens(prebuilt, input)),
  ("serde", input => @json.from_json(input)),
]

///|
test "JSON text: parse and decode" (b : @bench.T) {
  for entry in decoders {
    let (name, decode) = entry
    b.bench(name~, fn() {
      let input = try! @json.parse(fixture)
      b.keep(try! decode(input))
    })
  }
  b.bench(name="community-serde", fn() {
    b.keep(try! @community.from_string(fixture))
  })
}

///|
test "Parsed JSON: decode only" (b : @bench.T) {
  let input = @json.parse(fixture)
  for entry in decoders {
    let (name, decode) = entry
    b.bench(name~, fn() { b.keep(try! decode(input)) })
  }
}
