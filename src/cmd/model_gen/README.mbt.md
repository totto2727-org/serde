# model_gen

`model_gen` reads `#model.serde` and `#model.garde` attributes from the MoonBit source files you list.
It generates JSON codecs and validators without decoding or validating values.

## Usage

After [setup](#setup), put the annotated types in the `src/models` package.
From the module root, run:

```sh
model_gen src/models/endpoint.mbt --output src/models/endpoint.generated.mbt
moon check
```

The generator writes `src/models/endpoint.generated.mbt`.
`moon check` checks the generated code and the other source files in the module.
For multiple model files, use a separate [`dev_build` entry](https://github.com/totto2727-org/model#generate-code-with-dev_build) with its own output for each file. Moon can then reuse the outputs for unchanged files.

## Key features

- Process only the listed files, in the order you give them.
- Generate JSON codecs and validators in the same file in one run.
- Report invalid attributes with the source file and location.

## Prerequisites

- Use Moon `0.1.20261117` or a compatible version to check the generated code.
- To use a Nix setup option, enable flakes on Apple Silicon macOS or x86-64 Linux.

## Setup

Add the [Model library](https://mooncakes.io/docs/totto2727/model) to your MoonBit module.
See the [Model package configuration](https://github.com/totto2727-org/model#generate-code-with-dev_build) for imports and automatic generation.
Use a release that includes the attributes in your models.

### Run without installing

Use Nix to run the generator directly:

```sh
nix run github:totto2727-org/model -- --help
```

### Install

```sh
nix profile add github:totto2727-org/model
```

Add the `bin` directory of your Nix profile to `PATH` if your shell cannot find `model_gen`.

### Nix flake

Use the [Model overlay example](https://github.com/totto2727-org/model#nix-flake) to add `model_gen` to a development shell.

## API

For annotated models and generated code, see [Serde attributes](https://mooncakes.io/docs/totto2727/model/serde-codegen) and [Garde attributes](https://mooncakes.io/docs/totto2727/model/garde).

### Command reference

```console
$ model_gen --help
Usage: model_gen INPUT... --output OUTPUT
```

Pass one or more `.mbt` source files from the same MoonBit package.
The generator does not discover files from directories.
An attribute name in a comment or string does not generate code.

Keep the output in the same MoonBit package as the input types.

The generator writes the output on every successful run, even when the content is the same.
It does not overwrite handwritten files.
For duplicate annotated types, the error identifies both definitions.

| Exit status | Meaning |
| --- | --- |
| `0` | The generator succeeded or printed help. |
| `1` | A file or generation error occurred. |
| `2` | The arguments do not match the command syntax. |

The generator writes help to standard output and errors to standard error.

## Development

For repository maintenance instructions, see [AGENTS.md](https://github.com/totto2727-org/model/blob/main/AGENTS.md).

## License

[MIT](https://github.com/totto2727-org/model/blob/main/LICENSE)
