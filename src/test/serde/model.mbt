///|
/// A generated struct codec distinguishes missing fields from explicit null.
#derive(Eq, Debug)
#model.serde
pub(all) struct Record {
  required : Int32
  optional : String?
  #model.serde(default)
  count : Int32
  #model.serde(rename="displayName", aliases="legacy_name")
  name : String
  #model.serde(skip)
  transient : Int32
  #model.serde(skip_serializing_if="Option::is_none")
  omitted : Int32?
}

///|
/// Unknown fields are rejected only when the container opts in.
#derive(Eq, Debug)
#model.serde(deny_unknown_fields)
pub(all) struct StrictRecord {
  value : Int32
}

///|
/// Container casing applies to fields without changing explicit wire names.
#derive(Eq, Debug)
#model.serde(rename_all="camelCase")
pub(all) struct CamelRecord {
  first_name : String
  #model.serde(rename="fixed_name")
  last_name : String
}

///|
/// The external representation covers every supported constructor shape.
#derive(Eq, Debug)
#model.serde(rename_all="snake_case")
pub(all) enum External {
  Idle
  NewValue(Int32)
  Pair(String, Int32)
  Named(label~ : String, child~ : StrictRecord)
  #model.serde(rename="renamed")
  Special
  #model.serde(rename="Maybe")
  Maybe(String?)
}

///|
/// Internal tags coexist with named constructor payload fields.
#derive(Eq, Debug)
#model.serde(tag="type", rename_all="snake_case")
pub(all) enum Internal {
  Idle
  Named(value~ : Int32, note~ : String?)
}

///|
/// Adjacent tags keep discriminator and payload in separate members.
#derive(Eq, Debug)
#model.serde(tag="type", content="data", rename_all="snake_case")
pub(all) enum Adjacent {
  Idle
  Value(Int32)
  Pair(String, Int32)
  Named(value~ : Int32)
  Maybe(String?)
}

///|
/// Untagged decoding chooses the first matching constructor.
#derive(Eq, Debug)
#model.serde(untagged)
pub(all) enum Untagged {
  Integer(Int32)
  Text(String)
  Named(value~ : Int32)
}

///|
/// Nested generated codecs preserve collection and field error paths.
#derive(Eq, Debug)
#model.serde
pub(all) struct Envelope {
  records : Array[StrictRecord]
  event : External?
  nested : String??
}

///|
#model.serde(decode_only)
#derive(ToJson)
pub struct DecodeOnlyRecord {
  count : Int32
}

///|
#model.serde(tag="type", rename_all="snake_case", decode_only)
pub enum DecodeOnlyEvent {
  Done
  Data(DecodeOnlyRecord)
  Named(text~ : String)
}

///|
#model.serde
priv struct PrivateRecord {
  event : PrivateEvent
}

///|
#model.serde(rename_all="snake_case")
priv enum PrivateEvent {
  Closed
}

///|
test "PrivateRecord - derive codecs without exporting the internal wire type" {
  let input : Json = { "event": "closed" }
  let parsed : PrivateRecord = @json.from_json(input)
  assert_true(parsed.event is Closed)
  assert_eq(ToJson::to_json(parsed), input)
}

///|
#model.serde(deny_unknown_fields)
pub struct FixedPath {
  #model.serde(path=["part", "state", "status"])
  status : String
  #model.serde(path=["part", "state", "count"], default)
  count : Int32
  #model.serde(path=["part", "note"], skip_serializing_if="Option::is_none")
  note : String?
  #model.serde(path=["extras", "a/b~.c"], skip_serializing_if="Option::is_none")
  extra : String?
  #model.serde(path=["extras", "quote\"\\"], skip_serializing_if="Option::is_none")
  escaped : String?
  #model.serde(aliases="legacy")
  label : String
}

///|
#model.serde
pub struct Distance(Int32)

///|
#model.serde
pub struct Measurement(Distance, String?)

///|
#model.serde(decode_only)
priv struct PrivateTuple(Int32, Bool?)

///|
impl ToJson for PrivateTuple with fn to_json(self) {
  let PrivateTuple(first, second) = self
  { "first": first, "flag": second.unwrap_or(false) }
}

///|
test "private tuple struct - decode_only preserves the handwritten encoder" {
  let decoded : PrivateTuple = @json.from_json([3, true])
  assert_eq(ToJson::to_json(decoded), { "first": 3, "flag": true })
}

///|
#model.serde
pub struct GenericRecord[T, U] {
  #model.serde(path=["data", "items"])
  items : Array[T]
  #model.serde(default)
  fallback : U
}

///|
#model.serde
pub struct GenericBox[T](T)

///|
#model.serde
pub struct GenericPair[T, U](GenericBox[T], U?)

///|
#model.serde(tag="type", content="data")
pub enum GenericAdjacent[T, U] {
  Empty
  Positional(T)
  Named(value~ : U)
}

///|
#model.serde(untagged)
pub enum GenericUntagged[T] {
  Scalar(T)
  Batch(items~ : Array[T])
}

///|
#model.serde(decode_only)
pub struct ReadOnlyBox[T](T)

///|
#model.serde(encode_only)
pub(all) struct WriteOnlyRecord[T] {
  #model.serde(rename="id")
  identifier : T
}

///|
#model.serde(encode_only)
pub(all) struct WriteOnlyTuple[T](T, Bool)

///|
#model.serde(encode_only, tag="type", content="data")
pub(all) enum WriteOnlyEvent[T] {
  Value(T)
}

///|
#derive(Default)
pub struct DefaultOnly(Int32)

///|
#model.serde
pub struct WithSkipped[T, U] {
  value : T
  #model.serde(skip)
  hidden : U
}

///|
#model.serde
pub(all) struct DirectionalFields[Read, Write, Scratch] {
  #model.serde(skip_serializing, aliases="legacy_input")
  input : Read?
  #model.serde(skip_deserializing, default="empty_option")
  output : Write?
  #model.serde(skip, default="empty_array")
  scratch : Array[Scratch]
}

///|
fn[T] empty_option() -> T? {
  None
}

///|
fn[T] empty_array() -> Array[T] {
  []
}

///|
#model.serde(deny_unknown_fields)
pub(all) struct CallableFields {
  #model.serde(path=["settings", "value"], default="field_value", skip_serializing_if="CallableFields::omit_value")
  value : Int32?
  #model.serde(skip_deserializing, aliases="old_status")
  status : Int32
  #model.serde(skip, default="field_value")
  hidden : Int32?
  #model.serde(default)
  legacy_optional : Int32?
}

///|
fn field_value() -> Int32? {
  Some(42)
}

///|
fn CallableFields::omit_value(value : Int32?) -> Bool {
  value == Some(0)
}

///|
priv struct Code(Int32)

///|
fn encode_code(code : Code) -> Json {
  let Code(number) = code
  ToJson::to_json(number)
}

///|
fn decode_code(
  value : Json,
  path : @json.JsonPath,
) -> Code raise @json.JsonDecodeError {
  Code(@json.from_json(value, path~))
}

///|
fn Code::serialize(value : Code?) -> Json {
  match value {
    None => Json::null()
    Some(code) => encode_code(code)
  }
}

///|
fn Code::deserialize(
  value : Json,
  path : @json.JsonPath,
) -> Code? raise @json.JsonDecodeError {
  Some(decode_code(value, path))
}

///|
#model.serde
priv struct HookModel {
  #model.serde(serialize_with="encode_code", deserialize_with="decode_code", path=["meta", "id"])
  id : Code
  #model.serde(codec="Code")
  other : Code?
}

///|
#model.serde
priv struct FlattenedModel {
  #model.serde(flatten)
  extra : Map[String, Json]
  #model.serde(rename="id", aliases=["oldId"])
  identifier : Int32
  #model.serde(path=["meta", "active"])
  active : Bool
}

///|
test "field hooks replace JSON traits and receive the field path" {
  let input : Json = { "meta": { "id": 7 }, "other": 8 }
  let model : HookModel = @json.from_json(input)
  assert_eq(ToJson::to_json(model), input)
  let missing : HookModel = @json.from_json({ "meta": { "id": 7 } })
  assert_true(missing.other is None)
  let path = try {
    let _ : HookModel = @json.from_json({ "meta": { "id": "bad" } })
    fail("expected a field error")
  } catch {
    @json.JsonDecodeError((path, _)) => path.to_string()
    error => raise error
  }
  assert_eq(path, "/meta/id")
}

///|
fn decode_at_label(
  value : Json,
  path : @json.JsonPath,
) -> String raise @json.JsonDecodeError {
  let text : String = @json.from_json(value, path~)
  path.to_string() + ":" + text
}

///|
#model.serde(decode_only)
priv struct ScalarPaths {
  #model.serde(rename="a/b~c")
  text : String
  active : Bool
  #model.serde(deserialize_with="decode_at_label")
  label : String
}

///|
test "scalar fast paths preserve errors and pass context to custom decoders" {
  for active in [false, true] {
    let value : ScalarPaths = @json.from_json({
      "a/b~c": "text",
      "active": active,
      "label": "custom",
    })
    assert_eq(value.text, "text")
    assert_eq(value.active, active)
    assert_eq(value.label, "/label:custom")
  }
  let malformed : Array[(Json, String, String)] = [
    ({ "a/b~c": 5 }, "/a~1b~0c", "String::from_json: expected string"),
    (
      { "a/b~c": "text", "active": "true" },
      "/active",
      "Bool::from_json: expected boolean",
    ),
  ]
  for case_ in malformed {
    let (input, path, message) = case_
    let actual = try {
      let _ : ScalarPaths = @json.from_json(input)
      fail("expected a scalar decode error")
    } catch {
      @json.JsonDecodeError((path, message)) => (path.to_string(), message)
      error => raise error
    }
    assert_eq(actual, (path, message))
  }
}

///|
test "flatten decodes remaining keys without mutating the input" {
  let input : Json = { "oldId": 4, "meta": { "active": true }, "color": "blue" }
  let model : FlattenedModel = @json.from_json(input)
  assert_eq(model.extra, { "color": "blue" })
  assert_eq(input, { "oldId": 4, "meta": { "active": true }, "color": "blue" })
  assert_eq(ToJson::to_json(model), {
    "id": 4,
    "meta": { "active": true },
    "color": "blue",
  })
}

///|
test "panic flatten does not overwrite a parent's canonical keys or aliases" {
  ignore(
    ToJson::to_json(FlattenedModel::{
      extra: { "oldId": Json::null() },
      identifier: 4,
      active: true,
    }),
  )
}
