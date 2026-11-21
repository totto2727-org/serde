# Model development

See [README.md](README.md) for consumer setup and the JSON representations.

The Nix and CI setup comes from [template-moonbit-simple](https://github.com/totto2727-org/template-moonbit-simple/tree/c7d7f703669add8a4db6752925b2b8302bdbde6f).
The Nix shell puts the packaged native generator on `PATH` for fixture generation and the CLI tests.
The module defaults to native so the shared `moon test` runs the CLI tests too.

Keep the template's CI triggers and shared action references unless a project requirement calls for a change. The Mooncakes workflow publishes the root Model module on pushes to `main`. It does not publish the generator module. Do not replace the main-push trigger with a tag or release trigger.

## Package layout

- `src/serde/`: runtime helpers called by generated JSON implementations.
- `src/serde-codegen/`: attribute validation and source generation from the official MoonBit AST.
- `src/garde/` and `src/garde-codegen/`: independent value validation and the `#model.garde` generator. `model_gen` emits codecs and validators in one run.
- `src/cmd/model_gen/`: Admiral command for native, linear Wasm, and JavaScript on Node.js that reads MoonBit source and writes a codec file. It is a separate Moon module so users of the codec library do not need Admiral. `package.nix` uses checksum-pinned Mooncakes archives without changing the local registry cache. Admiral is resolved from the pinned Mooncakes index.
- `src/test/serde/`: round-trip tests that compile and run the generated codecs.
- `src/test/garde/`: test both generators together and verify that JSON decoding does not run validation.

## Validation

Run these commands from the repository root with the MoonBit toolchain on `PATH`. Use `nix develop .#ci` for the pinned toolchain:

```sh
moon check --deny-warn
moon test
moon test --target js
```

To build the CLI from source, create a Moon workspace that contains the Model library and `src/cmd/model_gen`. Moon fetches Admiral from Mooncakes.
From the Model checkout, run `moon build --target wasm --release ./src/cmd/model_gen` for linear Wasm or `moon build --target js --release ./src/cmd/model_gen` for Node.js.
The Nix package remains native.

After changing a generator, re-enter the Nix shell to use the rebuilt executable.
Regenerate and format the integration fixtures after changing a generator or an annotated model:

```sh
model_gen src/test/serde/model.mbt --output src/test/serde/serde.generated.mbt
model_gen src/test/garde/model.mbt --output src/test/garde/serde.generated.mbt
model_gen src/test/garde/codec_model.mbt --output src/test/garde/codec_model.generated.mbt
moon fmt src/test/serde src/test/garde
```

Only these packages' generated fixtures are tracked, so the generated changes can be reviewed with the models.
CI tests the committed fixtures.

Run `moon fmt` after editing MoonBit code and `(cd src/cmd/model_gen && moon fmt)` after editing the CLI.
Run `moon info` to inspect public signatures locally.
Do not commit generated package interfaces.
To change a wire-format behavior, update the generator and check it through a compiled fixture, not just through a source snapshot.

## Performance

Optimize valid inputs first. Measure the successful path with `moon bench` and keep work needed only for diagnostics off that path when practical.
Preserve useful errors. For changes that affect rejection, check that malformed inputs do not cause disproportionate CPU or memory use as input size grows.
