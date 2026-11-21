# JSON codec and validation benchmarks

## Recorded results

These are mean times per operation from one `moon bench` run on 2026-11-21, with 10 samples per case.
The run used the native release build on an Apple M1 Pro (arm64, macOS 27.2) with Moon `0.1.20261117` (`eb64713`) and `moonc` `v0.10.21+06da1ed44`.
Model `0.1.0` came from [commit `f03fc07`](https://github.com/totto2727-org/model/commit/f03fc07bda6ea3e1d178356512f367c47a17ca6e).
The comparison used Lens `0.4.4`, Community Serde `0.3.1`, and MoonModel `0.2.1`.
See [Run the comparison](#run-the-comparison) for the command and the sections below for the fixtures.

### JSON decoding

| Method | Core `Json` to model, no parsing | JSON text to model, parsing included |
| --- | ---: | ---: |
| Pattern matching | 317.67 ns | 6.72 µs |
| Lens, paths built per call | 2.63 µs | 8.95 µs |
| Lens, prebuilt paths | 491.23 ns | 6.78 µs |
| Model Serde | 430.58 ns | 6.76 µs |
| Community Serde | No core `Json` API | 3.62 µs |

### JSON encoding

| Method | Model to core `Json`, no stringification | Model to JSON text, stringification included |
| --- | ---: | ---: |
| Hand-written encoder | 997.85 ns | 2.26 µs |
| Model Serde | 761.73 ns | 2.22 µs |
| Community Serde | No core `Json` API | 1.32 µs |

### Community Serde in-memory conversion

Community Serde's JSON API reads and writes JSON text directly. Its in-memory [`Value` API](https://github.com/moonbit-community/serde.mbt/blob/0675e0435c35c1b645e5c110936c47c04e981cfe/data.mbt#L26-L36) uses a different representation from core `Json`.
The benchmark parses the full fixture into a `Value` before timing `from_value`. The `to_value` benchmark starts with the typed model and returns a `Value` without writing text.

| Operation | Mean time | Sample range |
| --- | ---: | ---: |
| `from_value`: Community `Value` to typed model | 2.59 µs | 2.56 to 2.61 µs |
| `to_value`: Typed model to Community `Value` | 1.55 µs | 1.53 to 1.56 µs |

### Validation

| Method | Validation only, no parsing or model conversion | JSON text to validated model, parsing included |
| --- | ---: | ---: |
| Garde | 413.02 ns | 1.88 µs |
| MoonModel | 14.06 µs | 15.24 µs |

The validation-only cases start from different inputs: Garde validates a typed model, and MoonModel validates a core `Json` value.
The JSON text cases start from the same string and return the same typed model.

## JSON codecs

Compare five ways to decode the same nested request from JSON text in a native release build.

| Method | Decoding operation |
| --- | --- |
| `pattern` | Match built-in `Json` object, string, Boolean, and array patterns. |
| `lens-per-call` | Build the 12 typed Lens paths and read them on each call. |
| `lens-prebuilt` | Reuse the same 12 typed Lens paths, built before timing. |
| `serde` | Call `@json.from_json` with the implementation from `model_gen`. |
| `community-serde` | Call community Serde's `@json.from_string` with its generated `Deserialize` implementation. |

For encoding to text, compare a hand-written encoder, the `ToJson` implementation from `model_gen`, and community Serde's generated `Serialize` implementation.
Lens is measured on decoding only. Its setters update an existing document, which is a different operation from encoding a typed record into a new one.

## Run the comparison

From the repository root, enter `nix develop .#ci` to use the pinned MoonBit toolchain and build the generator from this checkout.

```sh
cd bench
moon test . --target native --deny-warn
moon bench . --target native --release --deny-warn --no-parallelize
```

The workspace uses Serde and Garde from this checkout, Lens `0.4.4`, [MoonModel `0.2.1`](https://github.com/moonbitstack/moonmodel/tree/v0.2.1), and [community Serde `0.3.1`](https://github.com/moonbit-community/serde.mbt/tree/0675e0435c35c1b645e5c110936c47c04e981cfe).
Each `dev_build` entry in [`moon.pkg`](moon.pkg) and [`community/moon.pkg`](community/moon.pkg) writes a separate generated file for its model source. Do not add the generated files to Git.
Run on an idle machine and repeat the command before drawing conclusions from small differences.

## Codec input and timing

The [Lens benchmark fixture](https://github.com/totto2727-org/lens/blob/main/src/lens_bench_test.mbt) supplies the JSON document in [`input_wbtest.mbt`](input_wbtest.mbt).
All methods decode the same 12 typed values into equivalent records.
The required containers must be objects. Unknown properties are ignored, and the `tags` array accepts only strings.
The four methods that use core `Json` share MoonBit's `FromJson` rules for `Int32` and `Double`. The Lens paths use `custom` for those fields because Lens's built-in number decoders accept a different set of inputs.
The tests check the complete typed output and rejection of invalid required data. The libraries can differ in their accepted inputs, numeric rules, and errors.

- **JSON text: parse and decode**: Read the same JSON string on each call and return a typed record.
- **Parsed JSON: decode only**: Decode the same core `Json`, parsed before timing.
- **ToJson: encode to JSON value**: Encode the same typed request into a fresh core `Json`.
- **ToJson: encode and stringify**: Write the same typed request as JSON text.

The benchmarks use MoonBit's standard [`@bench.T`](https://mooncakes.io/docs/moonbitlang/core/bench) and pass each timed result to `b.keep` so the compiler cannot discard the result.
The encoding tests compare the JSON values, not the spelling of the output text, and check that decoding restores the original values. A codec error stops the run.

## Validation input and timing

Both validators check the same [group and member data](validation_model.mbt): label and name lengths, member count, and an inclusive age range for each member.
The fixture uses ASCII strings because Garde measures UTF-16 code units and JSON Schema measures Unicode code points.
The [validation test](validation_bench_wbtest.mbt) checks acceptance, rejection, and the number of diagnostics for invalid input before you run the benchmarks.
The benchmarks time valid input and the APIs that can return all diagnostics, not fail-fast validation.

| Measurement | Garde | MoonModel |
| --- | --- | --- |
| Validation only | Validate an existing typed record. | Check its existing `Json` with `Schema::faults`. |
| JSON text to a validated typed record | Parse with core JSON, decode with Serde, then validate the record. | Parse with core JSON, check the `Json`, then decode with the same Serde implementation. |

MoonModel builds its schema with `@verify.schema` before timing and reuses it in each iteration.
The validation-only rows start from each validator's native input, so they do not measure conversion or identical shape checks.
The JSON text rows start with the same string and return the same typed record.
Community Serde checks required fields and types during deserialization. It has no built-in length or range rules comparable to this workload, so it is not listed as a validator.
`moon bench` controls sampling and prints the statistics for each combination. These fixtures do not measure concurrent throughput or application-level logic.
