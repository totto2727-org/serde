# Garde attributes

Use `#model.garde` to generate validators for MoonBit values.
Run validation explicitly on decoded or manually constructed values.

## Usage

After [setup](#setup), define the JSON model in `src/models/endpoint.mbt`.
Garde generates the `EndpointDecoded` type with a typed URL field.

```mbt nocheck
///|
#model.serde
#model.garde
pub(all) struct Endpoint {
  #model.serde(rename="endpointUrl")
  #model.garde(url)
  url : String
}
```

Put this test in `src/models/endpoint_wbtest.mbt`.

```mbt nocheck
///|
test "round-trip an endpoint with Garde" {
  let input : Json = { "endpointUrl": "https://EXAMPLE.org:443/docs" }
  let wire : Endpoint = @json.from_json(input)
  guard wire.validate() is Ok(_) else { fail("invalid endpoint") }
  guard wire.to_decoded() is Ok(decoded) else {
    fail("could not decode endpoint")
  }
  guard decoded.to_encoded() is Ok(encoded) else {
    fail("could not encode endpoint")
  }
  assert_eq(encoded.to_json(), { "endpointUrl": "https://example.org/docs" })
}
```

`@json.from_json` reads the wire model with the generated Serde implementation.
`wire.validate()` checks the model without converting it.
`wire.to_decoded()` also validates, so omit the separate validation call if you only need the typed model.
`decoded.to_encoded()` converts the typed model back to `Endpoint` and validates it.
The URL formatter normalizes the host and removes the default port before `encoded.to_json()` writes the final JSON value.

## Key features

- Validate decoded values separately from JSON decoding.
- Collect multiple violations with field and index paths.
- Validate nested values and use custom rules with a typed context.
- Convert validated URL and IP fields to typed values and back.

## Prerequisites

See the [Model prerequisites](https://github.com/totto2727-org/model#prerequisites) for the shared Moon toolchain and generator requirements.

## Setup

Install `model_gen` and add the [`dev_build` rule](https://github.com/totto2727-org/model#generate-code-with-dev_build) to `src/models/moon.pkg`.
Import `totto2727/model/garde` in the model package.
For the JSON example above, also import `moonbitlang/core/json` and `totto2727/model/serde`.

## Typed model conversion

On a record without a validation context, `#model.garde` generates `Validate` and a `ModelDecoded` type. The original record remains the wire type.
Use `#model.garde(validate_only)` to skip conversions. Contextual records, tuple structs, and enums generate validation only.

- `to_decoded()` validates before converting. `to_encoded()` converts back and validates the result.
- The decoded constructor takes typed fields without validating them. Use labels when it takes two or more arguments.
- With a Serde encoder, `to_json()` returns `Json` on the wire record without validation and `Result[Json, @garde.Report]` on the decoded record after validation.

Direct URL, IP, and phone rules convert strings to `@garde.Url`, `@garde.Addr`, and `@garde.PhoneNumber`. Encoding can normalize the text.

## API

Call `value.validate()` for a public model with a generated validator, or `@garde.validate(value)` for any model that implements `Validate`.
For a model with a validation context, call `value.validate_with(context)` instead.
Use `report.violations()` to read violations and `issue.path.segments()` to read their typed `Field` and `Index` segments.
The report uses MoonBit field names, not JSON keys set by Serde.
Garde follows the explicit validation model of [Rust garde](https://docs.rs/garde/latest/garde/), but does not implement all its rules.

Each example shows an annotated model, the generated MoonBit code or the relevant excerpt, and behavior that is not visible from the code alone.
The examples use the standard MoonBit formatting.

### `#model.garde`, `required`, `length`, `range`, and `skip`

The type marker generates an implementation of `@garde.Validate`.
By default, a field must have a validation rule or `skip`.
Use a non-optional type if absence should fail during decoding. The following example checks a non-empty `String` and uses `required` on an optional field only to report its absence at validation time.

```mbt nocheck
///|
#model.garde
pub struct Contact {
  #model.garde(length(min="1"))
  label : String
  #model.garde(required, length(min="2", max="80"))
  name : String?
  #model.garde(range(min="0", max="120"))
  age : Int32
  #model.garde(skip)
  notes : String
}
```

This is the complete generated implementation.
`required` adds a violation for `None` without changing the type from `String?`. This lets an application collect a missing value together with other validation errors.
`required` does not reject `Some("")` by itself. On an optional field, the `length` rule runs only on `Some`.
`range` applies inclusive bounds, and `skip` omits `notes` from the implementation.

```mbt nocheck
///|
pub impl @garde.Validate for Contact with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  {
    let garde_value = garde_self.label
    let garde_path = garde_path.field("label")
    if @garde.length(garde_value, Some(1), None) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.name
    let garde_path = garde_path.field("name")
    if garde_value is None {
      garde_report.add(garde_path, "is required")
    }
    if garde_value is Some(garde_value) {
      if @garde.length(garde_value, Some(2), Some(80)) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
  }
  let garde_value = garde_self.age
  let garde_path = garde_path.field("age")
  if @garde.range(garde_value, Some(0), Some(120)) is Some(message) {
    garde_report.add(garde_path, message)
  }
}
```

`length` uses MoonBit's `String.length()` (UTF-16 code units) for strings and counts items for arrays, maps, and byte strings. Other types can implement `@garde.Length`.
Use `min`, `max`, both, or `equal` alone. Quote numeric literals because the MoonBit attribute parser does not accept bare numbers. `range` also accepts named constants.
For quoted literals, Garde discards type suffixes such as `L` and `F`, and the MoonBit compiler uses the field's type.
Named constants retain their declared type and must match the field.
Garde does not convert bounds to `Double` or check numeric limits itself.
Use `skip` alone on a field, payload, or variant.

### `ascii`, `alphanumeric`, `contains`, `prefix`, `suffix`, and `custom`

`ascii` accepts only ASCII characters. `alphanumeric` accepts Unicode alphabetic and numeric characters.
Use `length(min="1")` if an empty string should also fail.
`contains`, `prefix`, and `suffix` are case-sensitive and accept JSON-compatible escapes in their arguments.
A function passed to `custom` receives the field value and returns `None` on success or `Some(message)` on failure.

```mbt nocheck
///|
#model.garde
pub struct Credentials {
  #model.garde(ascii, alphanumeric)
  username : String
  #model.garde(contains("-"), prefix("ref-"), suffix("-ok"))
  reference : String
  #model.garde(custom(check_code))
  code : String
}

///|
fn check_code(code : String) -> String? {
  if code == "unset" {
    Some("choose a code")
  } else {
    None
  }
}
```

Each rule can add a separate violation to the same field path.
`custom(check_code)` generates a call to `check_code`, without a runtime lookup by name.

```mbt nocheck
    if @garde.ascii(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.alphanumeric(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.reference
    let garde_path = garde_path.field("reference")
    if @garde.contains(garde_value, "-") is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.prefix(garde_value, "ref-") is Some(message) {
      garde_report.add(garde_path, message)
    }
    if @garde.suffix(garde_value, "-ok") is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  let garde_value = garde_self.code
  let garde_path = garde_path.field("code")
  if check_code(garde_value) is Some(message) {
    garde_report.add(garde_path, message)
  }
```

### `email`, `url`, `ip`, `ipv4`, `ipv6`, and `phone_number`

Apply these rules to strings. For an optional string, validation skips `None` unless you also apply `required`.

```mbt nocheck
///|
#model.garde
struct ContactFormats {
  #model.garde(email)
  email : String
  #model.garde(url)
  website : String
  #model.garde(ip)
  address : String
  #model.garde(ipv4)
  address_v4 : String
  #model.garde(ipv6)
  address_v6 : String
  #model.garde(phone_number)
  phone : String
}
```

Generated checks inside `@garde.Validate::collect`:

```mbt nocheck
///|
pub impl @garde.Validate for ContactFormats with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  {
    let garde_value = garde_self.email
    let garde_path = garde_path.field("email")
    if @garde.email(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.website
    let garde_path = garde_path.field("website")
    if @garde.url(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.address
    let garde_path = garde_path.field("address")
    if @garde.ip(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.address_v4
    let garde_path = garde_path.field("address_v4")
    if @garde.ipv4(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  {
    let garde_value = garde_self.address_v6
    let garde_path = garde_path.field("address_v6")
    if @garde.ipv6(garde_value) is Some(message) {
      garde_report.add(garde_path, message)
    }
  }
  let garde_value = garde_self.phone
  let garde_path = garde_path.field("phone")
  if @garde.phone_number(garde_value) is Some(message) {
    garde_report.add(garde_path, message)
  }
}
```

| Rule | Accepted input and limits |
| --- | --- |
| `email` | A bare email address parsed by [MoonMail](https://mooncakes.io/docs/moonbitstack/moonmail), without a display name, angle brackets, comments, or a group. |
| `url` | An absolute URL, including schemes such as `mailto:` and `file:`. Uses [MoonURL](https://mooncakes.io/docs/moonbitstack/moonurl) in WHATWG mode. |
| `ip`, `ipv4`, `ipv6` | Bare IPv4 or IPv6 text, without a port, brackets, or zone identifier. IPv4 uses four decimal octets. Uses [MoonIP](https://mooncakes.io/docs/moonbitstack/moonip). |
| `phone_number` | An international number with a country calling code. Uses [dialnumber](https://mooncakes.io/docs/sssssurf/dialnumber) for numbering-plan checks and does not assume a default region. |

These rules do not contact an external service.
A valid email address or telephone number is not evidence that it is assigned or reachable.

MoonMail determines which address syntax to accept, including Unicode and quoted local parts such as `"a@b"@example.org`.
Garde does not add DNS, IDNA, or length checks.

### `pattern`

Use `pattern("...")` to check a `String` with a MoonBit regular expression.
Use `pattern(matcher)` to call a named `String -> Bool` function instead. The generated check reports a violation when `!matcher(garde_value)`.
The rule searches for a match anywhere in the string. Use `^` and `$` to check the whole string, as below.
Write regex backslashes as `\\` inside the quoted attribute.
The generator rejects malformed expressions. For an optional string, the rule runs only on `Some`.

```mbt nocheck
///|
#model.garde
pub struct Reference {
  #model.garde(pattern("^ID-[0-9]+\\.$"))
  code : String
}
```

The generated validator adds a violation at `code` if the expression does not match.

```mbt nocheck
  let garde_value = garde_self.code
  let garde_path = garde_path.field("code")
  if @garde.pattern(garde_value, "^ID-[0-9]+\\.$") is Some(message) {
    garde_report.add(garde_path, message)
  }
```

### `matches`

Use `matches(field)` directly on a record field to compare it with a sibling.
Use the sibling's MoonBit name, not its JSON key. The two fields must have the same type and support `Eq`.
The rule compares whole values. For two optional fields, `None` matches `None`, but does not match `Some`.

```mbt nocheck
///|
#model.garde
pub struct Confirmation {
  #model.garde(skip)
  code : String
  #model.garde(matches(code))
  repeated : String
}
```

The generated validator reports a mismatch at `repeated`, not `code`.

```mbt nocheck
  let garde_value = garde_self.repeated
  let garde_path = garde_path.field("repeated")
  if garde_value != garde_self.code {
    garde_report.add(garde_path, "must match code")
  }
```

### `allow_unvalidated`, `dive`, and `inner`

Use `allow_unvalidated` on a type or variant to permit unmarked fields.
Use `dive` to run the nested type's `Validate` implementation.
Use `inner` to apply one or more rules to each item of an `Array`, `ReadOnlyArray`, or `FixedArray`.

```mbt nocheck
///|
#model.garde(allow_unvalidated)
pub struct Directory {
  #model.garde(dive)
  owner : Contact
  #model.garde(inner(dive))
  contacts : Array[Contact]
  description : String
}
```

The generated implementation does not access `description`.
It passes `owner` directly to `Validate::collect` and loops over `contacts` with its indices, so a violation can be reported at `owner.name` or `contacts[0].name`.

```mbt nocheck
///|
pub impl @garde.Validate for Directory with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  {
    let garde_value = garde_self.owner
    let garde_path = garde_path.field("owner")
    @garde.Validate::collect(garde_value, garde_report, garde_path)
  }
  let garde_value = garde_self.contacts
  let garde_path = garde_path.field("contacts")
  for garde_index, garde_value in garde_value {
    let garde_path = garde_path.index(garde_index)
    @garde.Validate::collect(garde_value, garde_report, garde_path)
  }
}
```

### `field(index=...)` and `field(name=...)`

Set `index` to a quoted, zero-based index for a tuple or positional enum payload.
Set `name` to a label for a named enum payload.
On an enum, put the type marker on the enum and the selectors on the variants.

```mbt nocheck
///|
#model.garde(field(index="0", ascii))
pub struct Id(String)

///|
#model.garde
pub enum Update[T] {
  NoChange
  #model.garde(field(index="0", dive))
  Replace(T)
  #model.garde(field(name="label", length(min="1")))
  Rename(label~ : String)
  #model.garde(skip)
  Legacy(String)
}
```

The tuple-struct match adds the position to the report path.

```mbt nocheck
    Id(garde_inner) => {
      let garde_value = garde_inner
      let garde_path = garde_path.index(0)
      if @garde.ascii(garde_value) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
```

The enum match validates only the active variant, with paths such as `Replace[0]` or `Rename.label`.
The wildcard arm does nothing for unit and skipped variants.
`dive` on `T` adds a `Validate` bound.

```mbt nocheck
///|
pub impl[T : @garde.Validate] @garde.Validate for Update[T] with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  match garde_self {
    Replace(garde_inner) => {
      let garde_value = garde_inner
      let garde_path = garde_path.field("Replace").index(0)
      @garde.Validate::collect(garde_value, garde_report, garde_path)
    }
    Rename(label=garde_field_label) => {
      let garde_value = garde_field_label
      let garde_path = garde_path.field("Rename").field("label")
      if @garde.length(garde_value, Some(1), None) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
    _ => ()
  }
}
```

### `bounds`

A direct `length` check on `T` adds a `Length` bound.
Use `bounds` to specify a parameter's bounds when the needed traits cannot be inferred, for example when `dive` targets a wrapper around `T`.
Valid lists include `[Length]`, `[Validate, Length]`, `[Eq]`, and `[]` to suppress that parameter's inferred bounds.
`matches` infers an `Eq` bound when a compared field uses a type parameter.
Unused or skipped type parameters need no bound.

```mbt nocheck
///|
#model.garde(field(index="0", length(min="2")))
pub struct Sized[T](T)

///|
#model.garde(bounds(T, [Length]), field(index="0", dive))
pub struct Envelope[T](Sized[T])
```

Both implementations have a `Length` bound on `T`.
The bound for `Sized` comes from `length`, and the bound for `Envelope` comes from `bounds`.

```mbt nocheck
pub impl[T :  @garde.Length] @garde.Validate for Sized[T] with fn collect(
```

```mbt nocheck
pub impl[T :  @garde.Length] @garde.Validate for Envelope[T] with fn collect(
```

### `context`, `custom_with`, and `dive_with`

Use `context=Policy` to generate `validate_with` and `collect_with` methods instead of a `Validate` implementation.
`custom_with(check_count)` passes the field value and the context to `check_count`.
`dive_with` passes the same context to a nested validator, including under `inner`.
Ordinary rules and context-free `dive` can still be used on the same model.

```mbt nocheck
///|
pub struct Policy {
  max_count : Int32
}

///|
#model.garde(context=Policy)
pub struct Allocation {
  #model.garde(custom_with(check_count))
  count : Int32
}

///|
fn check_count(count : Int32, policy : Policy) -> String? {
  if count > policy.max_count {
    Some("exceeds quota")
  } else {
    None
  }
}

///|
#model.garde(context=Policy)
pub struct Request {
  #model.garde(inner(dive_with))
  allocations : Array[Allocation]
}
```

Call `allocation.validate_with(policy)` to start a report with the policy.
The generated collector passes that policy to your check.

```mbt nocheck
///|
pub fn Allocation::collect_with(
  garde_self : Allocation,
  garde_context : Policy,
  garde_report : @garde.Report,
  garde_path : @garde.Path,
) -> Unit {
  let garde_value = garde_self.count
  let garde_path = garde_path.field("count")
  if check_count(garde_value, garde_context) is Some(message) {
    garde_report.add(garde_path, message)
  }
}
```

```mbt nocheck
///|
pub fn Allocation::validate_with(
  self : Allocation,
  context : Policy,
) -> Result[Unit, @garde.Report] {
  @garde.validate_using(self, (value, report, path) => {
    value.collect_with(context, report, path)
  })
}
```

The generated request collector passes the policy and the item path to each allocation.

```mbt nocheck
  let garde_value = garde_self.allocations
  let garde_path = garde_path.field("allocations")
  for garde_index, garde_value in garde_value {
    let garde_path = garde_path.index(garde_index)
    garde_value.collect_with(garde_context, garde_report, garde_path)
  }
```

### `when`, `when_with`, `dive_with(field)`, and `transparent`

Use `when(predicate, rules...)` to apply rules only when `predicate(model)` is true. The predicate receives the entire model so it can read sibling fields. `when_with` also passes the typed context as the second argument.
Use `dive_with(field)` to pass a sibling field as the type-specific context for a nested value. `dive` without a context also works directly on arrays and string-keyed maps. The generated collector adds the item's index or key to the path.
Use `transparent` on a record or tuple struct with exactly one validated field. When another model dives into this wrapper, violations keep the wrapper's path without adding its inner field or tuple index.

```mbt nocheck
///|
#model.garde(transparent, field(index="0", length(min="3")))
struct Tag(String)

///|
#model.garde
struct PublishRequest {
  #model.garde(skip)
  published : Bool
  #model.garde(when(is_published, required, dive))
  tag : Tag?
}

///|
fn is_published(value : PublishRequest) -> Bool {
  value.published
}
```

Generated collectors:

```mbt nocheck
///|
impl @garde.Validate for Tag with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  match garde_self {
    Tag(garde_inner) => {
      let garde_value = garde_inner
      let garde_path = garde_path
      if @garde.length(garde_value, Some(3), None) is Some(message) {
        garde_report.add(garde_path, message)
      }
    }
  }
}

///|
impl @garde.Validate for PublishRequest with fn collect(
  garde_self,
  garde_report,
  garde_path,
) {
  let garde_value = garde_self.tag
  let garde_path = garde_path.field("tag")
  if is_published(garde_self) {
    if garde_value is None {
      garde_report.add(garde_path, "is required")
    }
    if garde_value is Some(garde_value) {
      @garde.Validate::collect(garde_value, garde_report, garde_path)
    }
  }
}
```

A published request with an absent or short tag reports `tag`, not `tag[0]`. An unpublished request skips these rules. Conditions and context selection do not change decoding.

## Development

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/model/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/model/blob/main/LICENSE)
