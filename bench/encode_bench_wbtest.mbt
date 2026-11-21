///|
fn encode_manual(request : Request) -> Json {
  {
    "requestId": request.request_id,
    "version": request.version,
    "user": {
      "name": request.user.name,
      "active": request.user.active,
      "age": request.user.age,
      "score": request.user.score,
      "metadata": { "tags": request.user.metadata.tags },
    },
    "project": {
      "id": request.project.id,
      "archived": request.project.archived,
    },
    "metrics": {
      "latencyMs": request.metrics.latency_ms,
      "attempts": request.metrics.attempts,
    },
    "payload": { "title": request.payload.title },
  }
}

///|
test "manual and generated encoders agree and preserve all modeled values" {
  let generated = ToJson::to_json(expected)
  assert_eq(generated, encode_manual(expected))
  let decoded : Request = @json.from_json(generated)
  assert_eq(decoded, expected)
}

///|
test "ToJson: encode to JSON value" (b : @bench.T) {
  b.bench(name="manual", fn() { b.keep(encode_manual(expected)) })
  b.bench(name="serde", fn() { b.keep(ToJson::to_json(expected)) })
}

///|
test "ToJson: encode and stringify" (b : @bench.T) {
  let community_request = @community.from_string(fixture)
  b.bench(name="manual", fn() { b.keep(encode_manual(expected).stringify()) })
  b.bench(name="serde", fn() { b.keep(ToJson::to_json(expected).stringify()) })
  b.bench(name="community-serde", fn() {
    b.keep(try! @community.to_string(community_request))
  })
}
