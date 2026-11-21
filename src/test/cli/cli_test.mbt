///|
async fn cli(dir : String, argv : ArrayView[String]) -> (Int32, String, String) {
  let (code, out, err) = @process.collect_output("model_gen", argv, cwd=dir)
  (code, out.text(), err.text())
}

///|
async fn model(dir : String, file : String, name : String) -> Unit {
  @fs.write_file("\{dir}/\{file}", "#model.serde\nstruct \{name}(Int)\n")
}

///|
async test "model_gen - usage goes to stdout for help and stderr for bad arguments" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  let usage = "Usage: model_gen INPUT... --output OUTPUT\n"
  assert_eq(cli(dir, ["--help"]), (0, usage, ""))
  assert_eq(cli(dir, ["first.mbt"]), (2, "", usage))
  assert_eq(cli(dir, ["--package", "."]), (2, "", usage))
  assert_eq(cli(dir, ["--output", "output.mbt"]), (2, "", usage))
}

///|
async test "model_gen generates codecs and validators together without overwriting handwritten code" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  @fs.write_file(
    "\{dir}/models.mbt",
    "#model.serde\n#model.garde\nstruct Both {\n  #model.garde(range(min=\"0\"))\n  value : Int\n}\n",
  )
  let argv = ["models.mbt", "--output", "serde.generated.mbt"]
  assert_eq(cli(dir, argv[:]), (0, "", ""))
  let output = "\{dir}/serde.generated.mbt"
  let generated = @fs.read_file(output).text()
  assert_true(generated.contains("impl ToJson for Both"))
  assert_true(generated.contains("impl @json.FromJson for Both"))
  assert_true(generated.contains("impl @garde.Validate for Both"))
  assert_false(@fs.exists("\{dir}/garde.generated.mbt"))
  let modified = @fs.mtime(output)
  @async.sleep(1100)
  assert_eq(cli(dir, argv[:]), (0, "", ""))
  assert_eq(@fs.read_file(output).text(), generated)
  assert_false(@fs.mtime(output) == modified)
  @fs.write_file(output, "handwritten\n")
  let (status, _, err) = cli(dir, argv[:])
  assert_eq(status, 1)
  assert_true(err.contains("refusing to overwrite"), msg=err)
  assert_eq(@fs.read_file(output).text(), "handwritten\n")
}

///|
async fn guarded_model(dir : String, file : String, name : String) -> Unit {
  @fs.write_file(
    "\{dir}/\{file}",
    "#model.garde(field(index=\"0\", ascii))\nstruct \{name}(String)\n",
  )
}

///|
async test "model_gen refreshes validators using only the listed files" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  model(dir, "codec.mbt", "CodecOnly")
  guarded_model(dir, "original.mbt", "Original")
  // The duplicate type would fail generation if the CLI scanned sibling files.
  guarded_model(dir, "unlisted.mbt", "Original")
  let output = "\{dir}/serde.generated.mbt"
  assert_eq(
    cli(dir, ["codec.mbt", "original.mbt", "--output", "serde.generated.mbt"]),
    (0, "", ""),
  )
  let original = @fs.read_file(output).text()
  assert_true(original.contains("impl @garde.Validate for Original "))
  assert_true(original.contains("impl ToJson for CodecOnly "))

  guarded_model(dir, "new.mbt", "Added")
  guarded_model(dir, "original.mbt", "Edited")
  assert_eq(
    cli(dir, [
      "codec.mbt", "original.mbt", "new.mbt", "--output", "serde.generated.mbt",
    ]),
    (0, "", ""),
  )
  let updated = @fs.read_file(output).text()
  assert_true(updated.contains("impl @garde.Validate for Added "))
  assert_true(updated.contains("impl @garde.Validate for Edited "))
  assert_false(updated.contains("Original"))

  assert_eq(
    cli(dir, ["codec.mbt", "--output", "serde.generated.mbt"]),
    (0, "", ""),
  )
  let codecs = @fs.read_file(output).text()
  assert_true(codecs.contains("impl ToJson for CodecOnly "))
  assert_false(codecs.contains("@garde.Validate"))
  @fs.write_file(
    "\{dir}/broken.mbt",
    "#model.garde(field(index=\"0\", required))\nstruct Broken(Int)\n",
  )
  let (status, _, err) = cli(dir, [
    "codec.mbt", "broken.mbt", "--output", "serde.generated.mbt",
  ])
  assert_eq(status, 1)
  assert_true(err.contains("required expects Option"), msg=err)
  assert_eq(@fs.read_file(output).text(), codecs)
}

///|
async test "model_gen - explicit inputs keep order" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  model(dir, "first.mbt", "First")
  model(dir, "second model.mbt", "Second")
  let argv = ["first.mbt", "second model.mbt", "--output", "output.mbt"]
  assert_eq(cli(dir, argv[:]), (0, "", ""))
  let path = "\{dir}/output.mbt"
  let before = @fs.read_file(path).text()
  guard before.find("impl ToJson for First ") is Some(first) else {
    fail("missing First implementation")
  }
  guard before.find("impl ToJson for Second ") is Some(second) else {
    fail("missing Second implementation")
  }
  assert_true(first < second)
}

///|
async test "model_gen - no overwrite and located errors on invalid sources" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  model(dir, "first.mbt", "First")
  @fs.write_file("\{dir}/handwritten.mbt", "handwritten\n")
  assert_eq(
    cli(dir, ["first.mbt", "--output", "handwritten.mbt"]),
    (1, "", "model_gen: refusing to overwrite handwritten.mbt\n"),
  )
  assert_eq(@fs.read_file("\{dir}/handwritten.mbt").text(), "handwritten\n")
  @fs.write_file(
    "\{dir}/broken.mbt",
    "#model.serde\nstruct Broken {\n  #model.serde(path=[])\n  value : Int\n}\n",
  )
  let (status, _, err) = cli(dir, [
    "broken.mbt", "--output", "broken.generated.mbt",
  ])
  assert_eq(status, 1)
  assert_true(err.has_prefix("model_gen: broken.mbt-3:3"), msg=err)
  assert_true(
    err.has_suffix(": path must be a non-empty array of string keys\n"),
    msg=err,
  )
  assert_false(@fs.exists("\{dir}/broken.generated.mbt"))
  model(dir, "duplicate.mbt", "First")
  let (status, _, err) = cli(dir, [
    "first.mbt", "duplicate.mbt", "--output", "duplicate.generated.mbt",
  ])
  assert_eq(status, 1)
  assert_true(err.has_prefix("model_gen: duplicate.mbt-"), msg=err)
  assert_true(
    err.contains(
      ": duplicate annotated type First (first defined at first.mbt-",
    ),
    msg=err,
  )
  assert_false(@fs.exists("\{dir}/duplicate.generated.mbt"))
}

///|
async test "model_gen - an explicit input without annotations emits only the header" {
  let dir = @fs.tmpdir(prefix="model_gen-test")
  defer @fs.rmdir(dir, recursive=true)
  model(dir, "model.mbt", "First")
  let argv = ["model.mbt", "--output", "serde.generated.mbt"]
  let output = "\{dir}/serde.generated.mbt"
  assert_eq(cli(dir, argv[:]), (0, "", ""))
  assert_true(@fs.read_file(output).text().contains("impl ToJson for First "))
  @fs.write_file("\{dir}/model.mbt", "struct First(Int)\n")
  assert_eq(cli(dir, argv[:]), (0, "", ""))
  assert_eq(
    @fs.read_file(output).text(),
    "// Generated by totto2727/model. Do not edit.\n",
  )
}
