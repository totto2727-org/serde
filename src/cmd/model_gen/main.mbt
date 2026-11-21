///|
const OUTPUT_OPTION = "output"

///|
const USAGE = "Usage: model_gen INPUT... --output OUTPUT"

///|
priv suberror CliError {
  Usage
  RefuseOverwrite(String)
}

///|
async fn run(args : ArrayView[String]) -> Unit {
  guard args is [.. files, flag, target] &&
    flag == "--" + OUTPUT_OPTION &&
    !files.is_empty() &&
    !target.is_empty() &&
    !target.has_prefix("-") &&
    files.all(file => {
      !file.is_empty() && !file.has_prefix("-") && file != target
    }) else {
    raise Usage
  }
  let inputs = @admiral.position_strings("INPUT")
  let output = @admiral.string(OUTPUT_OPTION)
  let app = @admiral.CliApp::CliApp(
    name="model_gen",
    positionals=[inputs],
    options=[output],
    run=Some(ctx => {
      generate(ctx.get_strings(inputs), ctx.get_string_required(output))
    }),
  )
  app.run(argv=Some(args.to_owned()))
}

///|
fn generate(inputs : ReadOnlyArray[String], output : String) -> Unit raise {
  let sources : Array[(String, String)] = []
  for input in inputs {
    sources.push((input, @fs.read_file_to_string(input)))
  }
  // Filter on the contiguous lexer token. Only the AST confirms an attribute.
  let codecs = @serde_codegen.generate_many(
    sources.filter(source => source.1.contains("#model.serde")),
  )
  let validation = @garde_codegen.generate_many(
    sources.filter(source => source.1.contains("#model.garde")),
  )
  let validation = validation
    .strip_prefix(@garde_codegen.GENERATED_HEADER + "\n")
    .unwrap()
  let generated = codecs + validation.to_owned()
  if @fs.path_exists(output) {
    let previous = @fs.read_file_to_string(output)
    let generated_before = previous.has_prefix(
      @serde_codegen.GENERATED_HEADER + "\n",
    )
    if !generated_before || sources.any(fn(source) { source.1 == previous }) {
      raise RefuseOverwrite(output)
    }
  }
  @fs.write_string_to_file(output, generated)
}

///|
#cfg(target="js")
fn command_arguments() -> ArrayView[String] {
  // Node's argv includes both the executable and the script path.
  @env.args()[2:]
}

///|
#cfg(not(target="js"))
fn command_arguments() -> ArrayView[String] {
  @env.args()[1:]
}

///|
async fn main {
  let args = command_arguments()
  if args is ["--help" | "-h"] {
    println(USAGE)
    return
  }
  run(args) catch {
    Usage => {
      eprintln(USAGE)
      @sys.exit(2)
    }
    RefuseOverwrite(path) => {
      eprintln("model_gen: refusing to overwrite \{path}")
      @sys.exit(1)
    }
    @serde_codegen.GenerateError(message)
    | @garde_codegen.GenerateError(message)
    | @fs.IOError(message) => {
      eprintln("model_gen: \{message}")
      @sys.exit(1)
    }
    error => {
      eprintln("model_gen: \{error}")
      @sys.exit(1)
    }
  }
}
