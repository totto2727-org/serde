# Serde attributes

Use `#model.serde` to generate `ToJson` and `@json.FromJson` implementations.
These traits control how a MoonBit type reads and writes JSON.

## Usage

See [Serde Usage](https://github.com/totto2727-org/model#usage) for a complete example that reads and writes the same `Endpoint` model with `@json.from_json` and `ToJson::to_json`.
For more field options, see the [`Profile` record](#record-options) and its [complete generated codec](#complete-generated-codec).

## Key features

- Generate JSON codecs for records, newtypes, tuple structs, and enums.
- Set JSON field names, read aliases, and nested object paths.
- Choose an enum representation or generate only one codec direction.

## Prerequisites

See the [Model prerequisites](https://github.com/totto2727-org/model#prerequisites) for the shared Moon toolchain and generator requirements.

## Setup

Install `model_gen` and add the [`dev_build` rule](https://github.com/totto2727-org/model#generate-code-with-dev_build) to the model package's `moon.pkg`.
Import `moonbitlang/core/json` and `totto2727/model/serde` in that package.

## API

Do not derive the same traits on an annotated type.
Serde generates code for MoonBit's `Json` type. See [flatten](#flatten-expand-a-child-object-into-its-parent) and [codec hooks](#codec-use-a-pair-of-conversion-functions) for field-level customization.

Each section shows a minimal annotated model, the generated MoonBit code or the relevant excerpt, and behavior that is not visible from the code alone.
The examples use the standard MoonBit formatting.
Generated bindings for named fields use the MoonBit field name, not the JSON key.

### `#model.serde`: newtypes and tuple structs

A newtype reads and writes its inner value. A tuple struct uses a fixed-length JSON array in declaration order.
An optional tuple element still needs a slot and writes `null` for `None`.

```mbt nocheck
///|
#model.serde
struct Id(Int32)

///|
#model.serde
struct Point(Int32, Int32)
```

Generated code:

```mbt nocheck
///|
pub impl ToJson for Id with fn to_json(self) {
  match self {
    Id(inner) => ToJson::to_json(inner)
  }
}

///|
pub impl @json.FromJson for Id with fn from_json(value, path) {
  let inner : Int32 = @json.from_json(value, path~)
  Id(inner)
}

///|
pub impl ToJson for Point with fn to_json(self) {
  match self {
    Point(item_0, item_1) =>
      Json::array([ToJson::to_json(item_0), ToJson::to_json(item_1)])
  }
}

///|
pub impl @json.FromJson for Point with fn from_json(value, path) {
  let values = @serde.tuple(value, 2, path)
  let item_0 : Int32 = @json.from_json(values[0], path=path.add_index(0))
  let item_1 : Int32 = @json.from_json(values[1], path=path.add_index(1))
  Point(item_0, item_1)
}
```

### `decode_only`: generate only a decoder

Use `decode_only` for a model that only reads JSON. Its fields do not need to implement `ToJson`.

```mbt nocheck
///|
#model.serde(decode_only)
struct InputId(Int32)
```

Generated code (there is no `ToJson` implementation):

```mbt nocheck
///|
pub impl @json.FromJson for InputId with fn from_json(value, path) {
  let inner : Int32 = @json.from_json(value, path~)
  InputId(inner)
}
```

### `encode_only`: generate only an encoder

```mbt nocheck
///|
#model.serde(encode_only)
struct OutputId(Int32)
```

Generated code:

```mbt nocheck
///|
pub impl ToJson for OutputId with fn to_json(self) {
  match self {
    OutputId(inner) => ToJson::to_json(inner)
  }
}
```

Use this for a model that only writes JSON. Its fields do not need `@json.FromJson`.
Do not combine `encode_only` and `decode_only`. With neither, Serde generates both traits.

### Record options

This record shows how the options in the sections below work together.

```mbt nocheck
///|
#model.serde(rename_all="camelCase", deny_unknown_fields)
struct Profile {
  display_name : String
  #model.serde(rename="email", aliases=["mail"])
  address : String
  #model.serde(path=["meta", "status"])
  status : String
  #model.serde(default)
  count : Int32
  #model.serde(skip)
  cache : Int32
  #model.serde(skip_serializing_if="Option::is_none")
  locale : String?
}
```

#### JSON input and output

Decode this JSON as `Profile`:

```json
{
  "displayName": "Aki",
  "mail": "a@example.net",
  "meta": { "status": "active" }
}
```

Encode the resulting `Profile` to get this JSON:

```json
{
  "displayName": "Aki",
  "email": "a@example.net",
  "meta": { "status": "active" },
  "count": 0
}
```

The decoder accepts `mail` as an alias and fills missing `count` with `0`.
The encoder writes the canonical key `email`, always omits `cache`, and omits `locale` when it is `None`.

#### Complete generated codec

These are the complete `ToJson` and `@json.FromJson` implementations for `Profile` in the generated file.

```mbt nocheck
///|
pub impl ToJson for Profile with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
  obj.set("displayName", ToJson::to_json(self.display_name))
  obj.set("email", ToJson::to_json(self.address))
  @serde.write_path(obj, ["meta", "status"], ToJson::to_json(self.status))
  obj.set("count", ToJson::to_json(self.count))
  if self.locale is Some(_) {
    obj.set(
      "locale",
      match self.locale {
        None => Json::null()
        Some(option_1) => ToJson::to_json(option_1)
      },
    )
  }
  Json::object(obj)
}

///|
pub impl @json.FromJson for Profile with fn from_json(value, path) {
  let obj = @serde.object(value, path)
  @serde.deny_unknown_paths(
    obj,
    [
      ["displayName"],
      ["email"],
      ["mail"],
      ["meta", "status"],
      ["count"],
      ["cache"],
      ["locale"],
    ],
    path,
  )
  let field_display_name : String = match obj.get("displayName") {
    Some(String(value)) => value
    Some(value) => @json.from_json(value, path=path.add_key("displayName"))
    None => @serde.missing_field(path.add_key("displayName"), "displayName")
  }
  let field_address : String = match
    @serde.field(obj, "email", ["mail"], path) {
    Some(String(value)) => value
    Some(value) => @json.from_json(value, path=path.add_key("email"))
    None => @serde.missing_field(path.add_key("email"), "email")
  }
  let field_status : String = match
    @serde.read_path(obj, ["meta", "status"], path) {
    (Some(value), at, _) => @json.from_json(value, path=at)
    (None, at, key) => @serde.missing_field(at, key)
  }
  let field_count : Int32 = match obj.get("count") {
    Some(value) => @json.from_json(value, path=path.add_key("count"))
    None => Default::default()
  }
  let field_cache : Int32 = Default::default()
  let field_locale : String? = match obj.get("locale") {
    Some(value) =>
      match value {
        Null => None
        option_1 => Some(@json.from_json(option_1, path=path.add_key("locale")))
      }
    None => None
  }
  {
    display_name: field_display_name,
    address: field_address,
    status: field_status,
    count: field_count,
    cache: field_cache,
    locale: field_locale,
  }
}
```

#### `rename_all`: change field or variant names

On a record, `rename_all="camelCase"` changes `display_name` to `displayName` in both directions. On an enum, it changes variant tags. An explicit `rename` or field `path` takes precedence.

Generated encoder excerpt:

```mbt nocheck
  obj.set("displayName", ToJson::to_json(self.display_name))
```

Generated decoder excerpt:

```mbt nocheck
///|
let field_display_name : String = match obj.get("displayName") {
  Some(String(value)) => value
  Some(value) => @json.from_json(value, path=path.add_key("displayName"))
  None => @serde.missing_field(path.add_key("displayName"), "displayName")
}
```

Accepted values: `lowercase`, `UPPERCASE`, `PascalCase`, `camelCase`, `snake_case`, `SCREAMING_SNAKE_CASE`, `kebab-case`, `SCREAMING-KEBAB-CASE`.

#### `rename` and `aliases`: choose write and read names

`rename="email"` sets the name in both directions. `aliases=["mail"]` adds a read-only name. The decoder rejects input that contains both names.

Generated encoder and decoder excerpts:

```mbt nocheck
  obj.set("email", ToJson::to_json(self.address))
```

```mbt nocheck
///|
let field_address : String = match @serde.field(obj, "email", ["mail"], path) {
  Some(String(value)) => value
  Some(value) => @json.from_json(value, path=path.add_key("email"))
  None => @serde.missing_field(path.add_key("email"), "email")
}
```

#### `path`: read and write a nested key

`path=["meta", "status"]` uses the literal object keys `meta` and `status`, not array indices.
It requires at least one key. Multiple fields can share a parent object.
It cannot be combined with `rename` or `aliases` on the same field.
No field path can be equal to or a prefix of another field path, including flat names and aliases.
The encoder creates parent objects only when it writes a field at that path.
The decoder applies the rule for missing values when a parent or leaf is missing, but rejects a present parent that is not an object.

Generated encoder and decoder excerpts:

```mbt nocheck
  @serde.write_path(obj, ["meta", "status"], ToJson::to_json(self.status))
```

```mbt nocheck
///|
let field_status : String = match
  @serde.read_path(obj, ["meta", "status"], path) {
  (Some(value), at, _) => @json.from_json(value, path=at)
  (None, at, key) => @serde.missing_field(at, key)
}
```

#### `default`: fill a missing field

Bare `default` calls `Default::default()` when a key is missing, or returns `None` for an optional field. Use `default="make_value"` to call a zero-argument function that returns the declared field type. This also lets an absent optional field default to `Some(...)`. A present JSON `null` still goes through the field decoder.

Generated decoder excerpt:

```mbt nocheck
///|
let field_count : Int32 = match obj.get("count") {
  Some(value) => @json.from_json(value, path=path.add_key("count"))
  None => Default::default()
}
```

#### `skip`: exclude a field from the codec

`skip` generates no read or write for `cache`. The decoder restores its default. For an optional field, it restores `None`.

Generated decoder excerpt:

```mbt nocheck
///|
let field_cache : Int32 = Default::default()
```

Use `skip_serializing` to omit the field from output without changing how input is decoded. Use `skip_deserializing` to ignore input for the field without changing its output. Both `skip` and `skip_deserializing` use a callable `default` if one is given. Otherwise, they use `None` for an optional field and `Default::default()` for other fields.

#### `skip_serializing_if`: omit a field conditionally

Use `skip_serializing_if="should_omit"` to call a function with the declared field value, including the `Option` wrapper if present. The function returns `Bool`. If it returns `true`, the encoder omits the key without calling the field serializer. This option does not change decoding.

`skip_serializing_if="Option::is_none"` is available only on optional fields. It omits `locale` when it is `None`. Without this attribute, the encoder writes `null`. Unless a callable default is specified, both a missing key and JSON `null` decode as `None`.

Callable defaults and predicates accept the same name syntax as codec hooks: `func`, `Type::method`, `@pkg.func`, and `@pkg.Type::method`.
For a nested `Option`, `None` and `Some(None)` both encode as `null` when written, and `null` decodes back as `None`.
At the first non-optional type, Serde uses that type's own codec. For example, the array codec handles `Array[T?]`.

Generated encoder excerpt:

```mbt nocheck
  if self.locale is Some(_) {
    obj.set(
      "locale",
      match self.locale {
        None => Json::null()
        Some(option_1) => ToJson::to_json(option_1)
      },
    )
  }
```

#### `deny_unknown_fields`: reject unrecognized keys

The decoder accepts canonical names, read aliases, and the declared object paths. It accepts but ignores fields marked with `skip`. It rejects input keys, aliases, and paths for fields marked with `skip_deserializing`. When a record has nested paths, the check also applies to the parent objects on those paths.

Generated decoder excerpt:

```mbt nocheck
  @serde.deny_unknown_paths(
    obj,
    [
      ["displayName"],
      ["email"],
      ["mail"],
      ["meta", "status"],
      ["count"],
      ["cache"],
      ["locale"],
    ],
    path,
  )
```

#### `flatten`: expand a child object into its parent

This model reads `{ "label": "desk", "color": "blue" }` and writes the same object.

```mbt nocheck
///|
#model.serde
pub struct WithExtras {
  label : String
  #model.serde(flatten)
  extra : Map[String, Json]
}
```

Generated encoder excerpt:

```mbt nocheck
  @serde.write_flattened(obj, ToJson::to_json(self.extra), ["label"])
```

Generated decoder excerpts:

```mbt nocheck
///|
let remaining = @serde.flattened_remainder(obj, ["label"])
```

```mbt nocheck
///|
let field_extra : Map[String, Json] = @json.from_json(remaining, path~)
```

The decoder passes the remaining keys to the flattened field after excluding the other fields' keys, aliases, and top-level path segments.
Use one non-optional flattened field per record and do not combine it with `deny_unknown_fields` or other options on the same field.
The MoonBit `ToJson` trait cannot return an encoding error. Encoding aborts if the field produces a non-object value or a key reserved by the parent.

#### `serialize_with` and `deserialize_with`: convert one field

Use either option to replace the trait call in that direction. The other direction keeps the default codec unless it also has a hook.

```mbt nocheck
///|
fn encode_count(value : Int32) -> Json {
  ToJson::to_json(value)
}

///|
fn decode_count(
  value : Json,
  path : @json.JsonPath,
) -> Int32 raise @json.JsonDecodeError {
  @json.from_json(value, path~)
}

///|
#model.serde
pub struct Count {
  #model.serde(serialize_with="encode_count", deserialize_with="decode_count")
  count : Int32
}
```

Generated encoder excerpt:

```mbt nocheck
  obj.set("count", encode_count(self.count))
```

Generated decoder excerpt:

```mbt nocheck
    Some(value) => decode_count(value, path.add_key("count"))
```

Use a function name, an imported function such as `@wire.encode`, or a qualified method such as `Wire::encode`.
The encoder receives the complete field value. The decoder receives the present JSON value and its path.
A missing value still uses the field's usual rules for optional values, defaults, or missing-field errors.
An explicit JSON `null` reaches the decoder hook unchanged.

#### `codec`: use a pair of conversion functions

`codec="Wire"` calls `Wire::serialize` and `Wire::deserialize`. `codec="@wire"` calls `@wire.serialize` and `@wire.deserialize` from an imported package.

```mbt nocheck
///|
priv struct Wire(Int32)

///|
fn Wire::serialize(value : Wire) -> Json {
  let Wire(number) = value
  ToJson::to_json(number)
}

///|
fn Wire::deserialize(
  value : Json,
  path : @json.JsonPath,
) -> Wire raise @json.JsonDecodeError {
  Wire(@json.from_json(value, path~))
}

///|
#model.serde
priv struct Packet {
  #model.serde(codec="Wire")
  id : Wire
}
```

Generated encoder excerpt:

```mbt nocheck
  obj.set("id", Wire::serialize(self.id))
```

Generated decoder excerpt:

```mbt nocheck
    Some(value) => Wire::deserialize(value, path.add_key("id"))
```

Do not combine `codec` with either individual hook on the same field.
The field type does not need to implement the JSON traits in the directions provided by hooks.

#### Combine directional skips and callable options

```mbt nocheck
///|
#model.serde
struct JobSettings {
  #model.serde(skip_serializing)
  token : String
  #model.serde(skip_deserializing)
  retries : Int32
  #model.serde(default="normal_priority", skip_serializing_if="is_normal_priority")
  priority : Int32
}

///|
fn normal_priority() -> Int32 {
  10
}

///|
fn is_normal_priority(value : Int32) -> Bool {
  value == normal_priority()
}
```

The encoder never writes `token`. The decoder requires `token`, ignores a supplied `retries`, and calls `normal_priority()` only if `priority` is missing.

Generated encoder excerpt:

```mbt nocheck
  obj.set("retries", ToJson::to_json(self.retries))
  if is_normal_priority(self.priority) == false {
    obj.set("priority", ToJson::to_json(self.priority))
  }
```

Generated decoder excerpt:

```mbt nocheck
///|
let field_token : String = match obj.get("token") {
  Some(String(value)) => value
  Some(value) => @json.from_json(value, path=path.add_key("token"))
  None => @serde.missing_field(path.add_key("token"), "token")
}

///|
let field_retries : Int32 = Default::default()

///|
let field_priority : Int32 = match obj.get("priority") {
  Some(value) => @json.from_json(value, path=path.add_key("priority"))
  None => normal_priority()
}
```

### Enum options

A single positional argument writes its value. Multiple positional arguments write a JSON array. Named arguments write a JSON object.

#### External tag and variant `rename`

With no representation option, a unit variant writes its tag as a JSON string. A payload variant writes an object with the variant tag as its key. Here `Text("hello")` writes `{ "message": "hello" }`.

```mbt nocheck
///|
#model.serde
pub enum External {
  Idle
  #model.serde(rename="message")
  Text(String)
}
```

Generated encoder:

```mbt nocheck
///|
pub impl ToJson for External with fn to_json(self) {
  match self {
    Idle => Json::string("Idle")
    Text(inner) => {
      let payload = ToJson::to_json(inner)
      Json::object({ "message": payload })
    }
  }
}
```

#### `tag`: put the tag in the payload object

`tag="type"` adds a tag to the object. A payload must use labeled constructor arguments unless the enum is decode-only. Here `NewMessage(text="hello")` writes `{ "type": "new_message", "text": "hello" }`.

```mbt nocheck
///|
#model.serde(tag="type", rename_all="snake_case")
pub enum Internal {
  Idle
  NewMessage(text~ : String)
}
```

Generated encoder arm:

```mbt nocheck
    NewMessage(text=field_text) => {
      let obj :Map[String, Json] = Map([])
      obj.set("text", ToJson::to_json(field_text))
      obj.set("type", Json::string("new_message"))
      Json::object(obj)
    }
```

With `decode_only`, one non-optional positional argument can read the complete object, including its tag.
For example, `{ "type": "Read", "text": "hello" }` decodes as `Read` with `kind` set to `"Read"`.

```mbt nocheck
///|
#model.serde(decode_only, tag="type")
pub enum InternalInput {
  Read(InternalData)
}

///|
#model.serde(decode_only, deny_unknown_fields)
pub struct InternalData {
  #model.serde(rename="type")
  kind : String
  text : String
}
```

Generated decoder arm:

```mbt nocheck
    "Read" => Read(@json.from_json(value, path~))
```

#### `content`: put the payload next to the tag

Combine `tag="type"` with `content="data"` to put the payload under a separate key. `Text("hello")` writes `{ "type": "Text", "data": "hello" }`. `Idle` has no `data` key.

```mbt nocheck
///|
#model.serde(tag="type", content="data")
pub enum Adjacent {
  Idle
  Text(String)
}
```

Generated encoder arm:

```mbt nocheck
    Text(inner) => {
      let tagged :Map[String, Json] = { "type": Json::string("Text") }
      let payload = ToJson::to_json(inner)
      tagged.set("data", payload)
      Json::object(tagged)
    }
```

#### `untagged`: use only the payload

`untagged` writes the payload without an enum tag. The decoder tries the variants in declaration order and returns the first match. Here `Text("hello")` writes `"hello"` and `Count(5)` writes `5`.
A unit variant writes `null`.

```mbt nocheck
///|
#model.serde(untagged)
pub enum Untagged {
  Text(String)
  Count(Int32)
}
```

Generated decoder:

```mbt nocheck
///|
pub impl @json.FromJson for Untagged with fn from_json(value, path) {
  @serde.untagged(value, path, [
    ("Text", serde_decode_Untagged_0),
    ("Count", serde_decode_Untagged_1),
  ])
}
```

Use a tagged representation if more than one variant can decode the same JSON value.

### Generic models

The generator adds `ToJson` and `@json.FromJson` bounds for the necessary type parameters in each direction. A field does not require the JSON trait for a direction it skips. A fallback to `Default::default()` can require `Default`, but a callable default does not add that bound.

```mbt nocheck
///|
#model.serde
pub struct Box[T](T)
```

Generated code:

```mbt nocheck
///|
pub impl[T : ToJson] ToJson for Box[T] with fn to_json(self) {
  match self {
    Box(inner) => ToJson::to_json(inner)
  }
}

///|
pub impl[T : @json.FromJson] @json.FromJson for Box[T] with fn from_json(
  value,
  path,
) {
  let inner : T = @json.from_json(value, path~)
  Box(inner)
}
```

### Decode errors

`@json.JsonDecodeError((path, message))` contains a JSON Pointer and a reason.
If the example path `["meta", "status"]` is missing because `meta` is absent, the decoder reports `/meta`, not `/meta/status`.
If no untagged variant matches, the message includes the path and reason for each variant.

## Development

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/model/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/model/blob/main/LICENSE)
