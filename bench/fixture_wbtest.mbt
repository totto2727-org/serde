///|
test "each decoder produces the complete expected output" {
  let input = @json.parse(fixture)
  for entry in decoders {
    let (_, decode) = entry
    assert_eq(decode(input), expected)
  }
}

///|
test "community Serde preserves the complete modeled JSON on a text round trip" {
  let request = @community.from_string(fixture)
  let output = @json.parse(@community.to_string(request))
  assert_eq(output, ToJson::to_json(expected))
  assert_eq((@json.from_json(output) : Request), expected)
}

///|
test "each decoder rejects invalid required data" {
  let invalid = [
    "null",
    fixture.replace(old="\"requestId\"", new="\"unusedId\""),
    fixture.replace(old="\"metadata\":{", new="\"unusedMetadata\":{"),
    fixture.replace(old="\"active\":true", new="\"active\":null"),
    fixture.replace(old="\"name\":\"Ada Lovelace\"", new="\"name\":7"),
    fixture.replace(old="[\"owner\",\"reviewer\",\"operator\"]", new="{}"),
    fixture.replace(old="\"reviewer\"", new="null"),
    fixture.replace(old="\"version\":7", new="\"version\":2147483648"),
    fixture.replace(old="\"latencyMs\":12.5", new="\"latencyMs\":\"12.5\""),
  ]
  for text in invalid {
    let input = @json.parse(text)
    for entry in decoders {
      let (name, decode) = entry
      match (Some(decode(input)) catch { _ => None }) {
        Some(_) => fail("\{name} accepted invalid input: \{text}")
        None => ()
      }
    }
    match (Some(@community.from_string(text)) catch { _ => None }) {
      Some(_) => fail("community-serde accepted invalid input: \{text}")
      None => ()
    }
  }
}
