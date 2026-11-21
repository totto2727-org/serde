# Rust Serde and garde feature matrix

Use this matrix to check whether a Rust model or validation rule has a MoonBit equivalent.
MoonBit Serde generates codecs for the standard `Json` value, not a format-independent serialization framework.
MoonBit Garde validates typed values independently of JSON and can generate a separate decoded record.

## Compared versions

| Project | Version | Exact source commit |
| --- | --- | --- |
| Rust Serde | [`1.0.229`](https://docs.rs/serde/1.0.229/serde/), tag `v1.0.229` | [`7fc3b4c30c94f73a96ebd1553f2b090d928fc3a8`](https://github.com/serde-rs/serde/tree/7fc3b4c30c94f73a96ebd1553f2b090d928fc3a8) |
| Rust Serde manual | `serde.rs` documentation snapshot | [`c4a897bc01fb358075ddd1f6235ed54081e88b84`](https://github.com/serde-rs/serde-rs.github.io/tree/c4a897bc01fb358075ddd1f6235ed54081e88b84) |
| Rust garde | [`0.23.0`](https://docs.rs/garde/0.23.0/garde/), tag `v0.23.0` | [`62b71b12102bfcef0041672ef9b7d6b0d5b74369`](https://github.com/jprochazk/garde/tree/62b71b12102bfcef0041672ef9b7d6b0d5b74369) |
| MoonBit Model (`totto2727/model`) | `0.1.0` | [`578386964342f57a3247804e9cb3e54041747256`](https://github.com/totto2727-org/model/tree/578386964342f57a3247804e9cb3e54041747256) |

The MoonBit row identifies a source snapshot, not the contents of a published Mooncakes archive with the same version.
The Model module contains the `serde` and `garde` packages.
This is a feature comparison based on upstream docs, local code, and local tests, not a cross-language conformance test.
It does not inventory format crates such as `serde_json`, third-party integrations, or every built-in Rust type implementation.

- **Supported:** MoonBit provides the same main capability, with different syntax where applicable.
- **Partial:** MoonBit provides a subset or differs in accepted input or output.
- **Not provided:** There is no corresponding built-in feature or generator option. Application code can still implement some of these behaviors.
- **MoonBit extension:** The project provides a feature with no direct counterpart in the corresponding Rust library.

## Serde

The Rust baseline is the [data model][serde-data-model], [container attributes][serde-containers], [field attributes][serde-fields], [variant attributes][serde-variants], and [enum representations][serde-enums].
For MoonBit syntax and examples, see [Serde attributes](../src/serde-codegen/README.mbt.md).

### Framework and data model

| Rust Serde feature | MoonBit status | MoonBit behavior |
| --- | --- | --- |
| Derive or implement `Serialize` and `Deserialize` separately | Supported | `#model.serde` generates `ToJson` and `@json.FromJson`. Use `encode_only` or `decode_only` to generate one direction. Implement the standard traits by hand when necessary. |
| Struct, tuple struct, newtype, enum, and generic models | Supported | Supports named record fields, positional tuples, enum unit and payload variants, and inferred generic constraints. One-field tuple structs use the inner JSON value. |
| Primitive and collection codecs, typed numeric kinds, bytes, and map keys | Partial | Fields use MoonBit's standard JSON traits or custom hooks. Values must have a JSON representation. JSON objects have string keys, and JSON numbers do not carry Rust's integer and float type distinctions. |
| `Serializer`, `Deserializer`, `Visitor`, and custom data formats | Not provided | Codecs work with a `Json` tree, not a stream or a format-independent visitor. Parse and print JSON with the standard library. |
| Borrowed or zero-copy decoding, `DeserializeSeed`, and in-place decoding | Not provided | No equivalent API for borrowing from input, passing state to the traversal, or updating an existing value while decoding. |
| Format-defined errors from serialization and deserialization | Partial | `@json.FromJson` can raise a JSON decoding error with a path. Standard `ToJson` returns `Json` rather than a serialization error. |
| Cargo feature flags, such as `derive`, `std`, `alloc`, `rc`, and `unstable` | Not provided | Rust package and runtime configuration do not apply to MoonBit. See the [Rust feature flag list][serde-features]. |

### Container attributes

| Rust Serde attribute or representation | MoonBit status | MoonBit behavior |
| --- | --- | --- |
| `rename` | Not provided | No option to rename the container itself. Record fields and enum variants have their own `rename`. |
| `rename_all` | Partial | The eight named case styles apply to record fields or enum variant names. There is no separate naming rule for serialization and deserialization. |
| `rename_all_fields` | Not provided | Enum payload labels retain their MoonBit names. |
| `deny_unknown_fields` | Partial | Works on records, not enums. Cannot be combined with `flatten`. |
| External tagging | Supported | Default for enums. Unit variants are strings. Other variants use an object with the variant name as its key. |
| `tag` (internal tagging) | Partial | Supports unit and labeled payload variants. A single non-optional positional object payload is supported only in `decode_only` mode. Not supported on structs. |
| `tag` with `content` (adjacent tagging) | Supported | Uses separate keys for the tag and payload. |
| `untagged` | Supported | Tries variants in declaration order and uses the first successful match. Input shape and diagnostic details depend on the generated MoonBit codecs. |
| `bound` | Partial | Infers MoonBit trait constraints by direction. There is no Serde attribute to override them. |
| `default` and `default = "path"` | Not provided | There is no whole-container default. Use field defaults. |
| `transparent` | Partial | A one-field positional newtype is transparent by default. No attribute makes a named record transparent. |
| `from`, `try_from`, `into` | Not provided | No generated whole-container conversion hooks. Use custom trait implementations or convert separately. |
| `remote`, `crate` | Not provided | No remote derive or attribute to set the generated Serde crate path. |
| `expecting` | Not provided | No override for generated expectation text. |
| `variant_identifier`, `field_identifier` | Not provided | No generated deserializer for field or variant identifiers. |

### Record fields and enum variants

| Rust Serde attribute | MoonBit status | MoonBit behavior |
| --- | --- | --- |
| Field `rename`, `alias` | Supported | `rename` sets one read and write key. `aliases` adds read-only alternatives. The write key is still accepted as input. |
| Direction-specific field `rename` | Not provided | An alias can accept an older or alternate input name but cannot make the output name invalid on input. |
| Field `default`, `default = "path"` | Supported | Uses `Default`, `None`, or a named zero-argument function for absent keys. A present `null` goes through the field decoder. |
| Field `skip`, `skip_serializing`, `skip_deserializing`, `skip_serializing_if` | Supported | Omit either direction and use a named predicate or `is_none` for conditional omission. A skipped input field receives its configured default. |
| Field `serialize_with`, `deserialize_with`, `with` | Supported | Use individual hooks or `codec="Wire"`/`codec="@wire"` for a pair of named functions. Hooks operate on `Json`, not a Serde `Serializer` or `Deserializer`. |
| Field `flatten` | Partial | One non-optional field per record. It encodes to a JSON object and receives remaining keys on input. Cannot be combined with other attributes on that field or `deny_unknown_fields` on the record. |
| Field `borrow`, `bound`, `getter` | Not provided | No borrowed field decoding, field-specific bound override, or remote-field getter attribute. |
| Variant `rename` | Partial | Changes one tag name in both directions. |
| Variant `alias`, `rename_all`, `skip`, `skip_serializing`, `skip_deserializing` | Not provided | These options do not apply to MoonBit enum variants. |
| Variant `serialize_with`, `deserialize_with`, `with`, `bound`, `borrow` | Not provided | The generator supports only `rename` on an individual Serde variant. Record field attributes do not apply directly to enum payloads or tuple elements. |
| Variant `other`, `untagged` | Not provided | No catch-all variant and no per-variant override of the enum representation. |
| Nested key mapping | MoonBit extension | `path=[...]` reads and writes a field through nested JSON object keys. It cannot be combined with `rename` or `aliases` on the same field. |

## Garde

The Rust baseline is the [garde README][garde-readme], [crate API][garde-api], and [Cargo feature definitions][garde-cargo].
For MoonBit syntax and examples, see [Garde attributes](../src/garde/README.mbt.md).

### Validation rules

| Rust garde rule | MoonBit status | MoonBit behavior |
| --- | --- | --- |
| `required` and `Option` handling | Supported | `required` reports `None`. Most value rules run only on `Some`. `matches` is an exception and compares the whole field. |
| `ascii` | Supported | Accepts only ASCII characters. |
| `alphanumeric` | Partial | Uses MoonBit's Unicode alphabetic and numeric predicates. The character set can differ from Rust's. |
| `email`, optional `email-idna` | Partial | Uses MoonMail to parse one bare mailbox without additional IDNA, DNS, or length checks. Rust garde uses an HTML5-oriented rule with optional IDNA support. |
| `url` | Supported | Uses MoonURL in WHATWG mode and requires a scheme. Exact acceptance and normalization can differ from Rust's `url` crate. |
| `ip`, `ipv4`, `ipv6` | Supported | Uses MoonIP for bare addresses, with no zone identifier. The version-specific rules check the address family. |
| `phone_number` | Partial | Uses dialnumber for numbering-plan validation with no default region. Metadata and accepted spellings can differ from Rust's `phonenumber` crate. |
| `credit_card` | Not provided | Intentionally omitted. |
| `length` | Partial | Supports inclusive `min`/`max` and `equal`, standard container counts, and a custom `Length` trait. `String` counts UTF-16 code units. There is no mode selector for Rust garde's `simple`, `bytes`, `chars`, `graphemes`, or `utf16`. |
| `range` | Partial | Supports inclusive `min`/`max` and `equal`. A quoted MoonBit numeric literal is typed by the field. Named constants must have that same type. No arbitrary bound expressions or independent range checks at generation time. |
| `contains`, `prefix`, `suffix` | Supported | Case-sensitive string rules with literal arguments. |
| `matches` | Supported | Compares same-type sibling fields on a record using `Eq`. The path points to the field carrying the rule. |
| `pattern` with a literal or a `Matcher` | Partial | Uses MoonBit regex syntax for literal patterns and a named `String -> Bool` function for custom matchers. Does not implement Rust's `Matcher` trait. |
| `custom` | Partial | Calls a named function returning `String?`. Use `custom_with` to pass typed context. Inline closures or arbitrary expressions in attributes are not supported. |
| `if(cond = ...)` | Partial | `when` calls a named predicate with the model, and `when_with` also passes the validation context. Predicates can read siblings. Attributes do not embed arbitrary expressions. |
| `dive`, including context override | Partial | Validates nested values and supported collections. Use `dive_with` to forward the current context or `dive_with(field)` to pass a sibling field. No arbitrary context expression. |
| `inner` | Partial | Applies rules recursively to elements of `Array`, `ReadOnlyArray`, or `FixedArray`. The supported container set differs from Rust. |
| `skip`, `allow_unvalidated` | Supported | Skip individual fields or variants, or allow unmarked fields using `allow_unvalidated`. |

### Generation and integration

| Rust garde feature | MoonBit status | MoonBit behavior |
| --- | --- | --- |
| Derive or implement `Validate` for structs and enums | Supported | `#model.garde` generates validation for records, tuple structs, and enums. Hand-written collectors can report at a field, index, or model path. |
| Newtype `transparent` validation | Supported | For a record or tuple struct with one validated field, keep the wrapper's path instead of appending that field or index. |
| Generic models and nested bounds | Partial | Infers relevant bounds for direct uses of type parameters. Use `bounds` for supported explicit traits such as `Length`, `Validate`, and `Eq`. |
| `Validate::Context` and access to `self` or context in rules | Partial | `context=Type` generates `validate_with` and `collect_with` instead of a context-associated `Validate` implementation. Named callbacks can receive context, but bounds cannot use context expressions. |
| Error reports, structured paths, and accumulation | Supported | Collects multiple string messages and exposes typed field/index path segments. Names come from the model, not JSON aliases. |
| `Unvalidated<T>` and `Valid<T>` wrappers | Not provided | No generic type that proves a value passed validation. `ModelDecoded` is a separate record with a public constructor that does not run wire validation. |
| I18n and report serialization (`serde` feature) | Not provided | No built-in translation hook or Serde-compatible format for reports. Applications can translate or serialize their own errors. |
| Rule-specific traits and `adapt` | Partial | Implement `Length`, use `custom`, or implement `Validate` directly. No general per-rule adapter lookup. |
| Cargo rule toggles and Rust-specific integrations | Not provided | There are no Cargo-style feature flags for rule packages, `js-sys`, or `rust_decimal` support. The Rust README's web-framework integrations are separate crates. |
| Typed wire/model conversion | MoonBit extension | Ordinary records get a `ModelDecoded` type, `to_decoded()` and `to_encoded()`. Direct URL, IP, and phone rules use the underlying libraries' types in the decoded record. `validate_only`, contextual records, tuple structs, and enums generate validation without a decoded record. |

The [typed conversion API](../src/garde/README.mbt.md#typed-model-conversion) validates in both directions.
The decoded constructor takes already-typed fields but does not run all wire constraints, and encoding may normalize text.
Apply rules that depend on external state in domain code, after decoding.

## Implementation references

- Serde: [attribute parsing](../src/serde-codegen/parse.mbt), [codec emission](../src/serde-codegen/emit.mbt), and [integration tests](../src/test/serde).
- Garde: [validation rules](../src/garde-codegen/generate.mbt), [type options](../src/garde-codegen/types.mbt), [typed conversions](../src/garde-codegen/codec.mbt), and [integration tests](../src/test/garde).

[serde-data-model]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/data-model.md
[serde-containers]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/container-attrs.md
[serde-fields]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/field-attrs.md
[serde-variants]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/variant-attrs.md
[serde-enums]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/enum-representations.md
[serde-features]: https://github.com/serde-rs/serde-rs.github.io/blob/c4a897bc01fb358075ddd1f6235ed54081e88b84/_src/feature-flags.md
[garde-api]: https://docs.rs/garde/0.23.0/garde/
[garde-readme]: https://github.com/jprochazk/garde/blob/62b71b12102bfcef0041672ef9b7d6b0d5b74369/README.md
[garde-cargo]: https://github.com/jprochazk/garde/blob/62b71b12102bfcef0041672ef9b7d6b0d5b74369/garde/Cargo.toml
