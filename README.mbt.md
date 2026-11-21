# Model for MoonBit

Model provides two packages: Serde for JSON codecs and Garde for validation and typed model conversion.
Add `#custom.serde` to a type to control how it reads and writes JSON.

This project is inspired by Rust's [Serde](https://serde.rs/) for serialization and [garde](https://docs.rs/garde/latest/garde/) for validation.

## Usage

After [setup](#setup), define the JSON model in `src/models/endpoint.mbt`.

```mbt nocheck
///|
#custom.serde
pub(all) struct Endpoint {
  #custom.serde(rename="endpointUrl")
  url : String
}
```

Put this test in `src/models/endpoint_wbtest.mbt`.

```mbt nocheck
///|
test "round-trip an endpoint with Serde" {
  let input : Json = { "endpointUrl": "https://EXAMPLE.org:443/docs" }
  let wire : Endpoint = @json.from_json(input)
  assert_eq(ToJson::to_json(wire), input)
}
```

`@json.from_json` and `ToJson::to_json` use the generated Serde implementations.
Both use the JSON key `endpointUrl` and preserve the URL string as written.

## Key features

- Use the standard MoonBit `ToJson` and `@json.FromJson` traits.
- Generate codecs for records, enums, newtypes, and tuple structs, including generic types.
- Set JSON field names, aliases, defaults, and nested object paths.
- Select external, internal, adjacent, or untagged enum representations.
- Get source locations for generation errors and JSON paths for decoding errors.
- Run Garde validation separately from JSON decoding.

## Prerequisites

- Use Moon `0.1.20261117` or a compatible version to check the generated code.
- To use a Nix setup option, enable flakes on Apple Silicon macOS or x86-64 Linux.

## Setup

From the root of your MoonBit module, add the [Model library](https://mooncakes.io/docs/totto2727/model):

```sh
moon add totto2727/model
```

### Install the generator

```sh
nix profile add github:totto2727-org/model
```

Keep `model_gen` on `PATH` so Moon can run it.

### Nix flake

Use the Model overlay to add `model_gen` to your development shell instead of installing it to your profile.
Set `system` to `aarch64-darwin` or `x86_64-linux`.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    model.url = "github:totto2727-org/model";
  };

  outputs = { nixpkgs, model, ... }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ model.overlays.default ];
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.model_gen ];
      };
    };
}
```

### Generate code with `dev_build`

`src/models/moon.pkg`:

```mbt nocheck
///|
import {
  "moonbitlang/core/json",
  "totto2727/model/serde",
}

rule(name: "model_gen", command: "model_gen $input --output $output")

dev_build(
  rule: "model_gen",
  input: "endpoint.mbt",
  output: "endpoint.generated.mbt",
)
```

Run `moon check`, `moon build`, or `moon test` as usual. Moon runs `model_gen` before it compiles the package.
Use paths relative to `moon.pkg` in `input` and `output`.
Add a separate `dev_build` entry with a distinct output for each annotated source file in the package.
For example, if the package also contains `contact.mbt`, add this entry to the same `moon.pkg`:

```mbt nocheck
dev_build(rule: "model_gen", input: "contact.mbt", output: "contact.generated.mbt")
```

Do not group model files in one `input` list: separate entries let Moon regenerate only the changed file's output and reuse the others.
The generator does not scan the directory for additional models.
If you remove a model file, also remove its `dev_build` entry and generated output.
The same rule generates both Serde codecs and Garde validators. For Garde models, also import `totto2727/model/garde`.
See MoonBit's [package configuration](https://github.com/moonbitlang/moonbit-docs/blob/main/next/toolchain/moon/package.md) for more about `dev_build`.

## API

Use the Mooncakes version selector to read the documentation for the version you installed.

- [Serde API](https://mooncakes.io/docs/totto2727/model/serde): Runtime helpers used by generated JSON codecs.
- [Serde attributes](https://mooncakes.io/docs/totto2727/model/serde-codegen): `#custom.serde` examples and generated codec excerpts.
- [Garde API and attributes](https://mooncakes.io/docs/totto2727/model/garde): Validation types, `#custom.garde` examples, and generated validator excerpts.

For manual generation and command-line options, see the [`model_gen` README](https://github.com/totto2727-org/model/tree/main/src/cmd/model_gen).

## Development

See the [Rust Serde and garde feature matrix](docs/upstream-feature-matrix.md) for supported features, differences, and the source versions used for comparison.

See the [Serde and Garde benchmark results](bench/README.md#recorded-results) for measurements with and without JSON parsing.

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/model/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/model/blob/main/LICENSE)

_This README follows the [share-artifact guidance](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/SKILL.md) and [README template](https://raw.githubusercontent.com/totto2727-org/agent/refs/heads/main/plugins/totto2727-coding/skills/share-artifact/readme/template.md)._
