///|
test "Community Serde Value codecs preserve all modeled fields" {
  let input : @community_serde.Value = @community_json.from_string(fixture)
  let request : @community.Request = @community_serde.from_value(input)
  let expected_json = ToJson::to_json(expected)
  assert_eq(@json.parse(@community.to_string(request)), expected_json)

  let request = @community.from_string(fixture)
  let output = @community_serde.to_value(request)
  assert_eq(@json.parse(@community_json.to_string(output)), expected_json)
}

///|
test "Community Serde Value: decode and encode without JSON text" (b : @bench.T) {
  let input : @community_serde.Value = @community_json.from_string(fixture)
  let request = @community.from_string(fixture)
  b.bench(name="from_value", fn() {
    let decoded : @community.Request = try! @community_serde.from_value(input)
    b.keep(decoded)
  })
  b.bench(name="to_value", fn() {
    b.keep(try! @community_serde.to_value(request))
  })
}
