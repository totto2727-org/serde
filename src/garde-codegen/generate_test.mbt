///|
test "reject unsupported garde codec declarations" {
  for
    (source, expected) in [
      ("#model.garde(codec)\nstruct S(String)", "requires a record struct"),
      (
        "#model.garde(codec, context=C)\nstruct S { value : String }", "does not support contextual validation",
      ),
      (
        "#model.garde\nstruct S {\n  #model.garde(url, phone_number)\n  value : String\n}",
        "supports one URL, IP, or phone number format per field",
      ),
      (
        "#model.garde(codec, validate_only)\nstruct S { value : String }", "unknown, invalid, or repeated #model.garde option",
      ),
    ] {
    let result = Ok(@garde_codegen.generate_many([("codec.mbt", source)])) catch {
      @garde_codegen.GenerateError(message) => Err(message)
    }
    guard result is Err(message) else { fail("accepted \{source}") }
    assert_true(message.contains(expected), msg=message)
  }
}

///|
test "codec bindings use field names rather than positions" {
  let source =
    #|#model.garde
    #|struct Endpoint {
    #|  #model.garde(url)
    #|  url : String
    #|  #model.garde(ip)
    #|  allowed_ip : String?
    #|}
  let generated = @garde_codegen.generate_many([("endpoint.mbt", source)])
  assert_true(generated.contains("Some(garde_decoded_url)"))
  assert_true(generated.contains("let garde_decoded_allowed_ip ="))
}

///|
test "validate_only keeps validation and omits the codec" {
  let source =
    #|#model.garde(validate_only)
    #|struct Endpoint {
    #|  #model.garde(url)
    #|  url : String
    #|}
  let generated = @garde_codegen.generate_many([("endpoint.mbt", source)])
  assert_true(generated.contains("impl @garde.Validate for Endpoint"))
  assert_false(generated.contains("EndpointDecoded"))
  assert_false(generated.contains("Endpoint::to_decoded"))
}

///|
test "reject invalid rules at the field's source location" {
  for
    (attribute, field_type, expected) in [
      ("length(min=2)", "String", "malformed #model.garde"),
      ("length(min=\"-1\")", "String", "bounds must be non-negative"),
      (
        "range(min=\"1 + 2\")", "Int", "must be a quoted MoonBit numeric literal",
      ),
      ("range(min=\"true\")", "Int", "must be a quoted MoonBit numeric literal"),
      ("range(min=\"1\", equal=\"2\")", "Int", "equal cannot be combined"),
      ("length(min=\"1\", equal=\"2\")", "String", "equal cannot be combined"),
      ("inner(required)", "String", "inner expects an Array"),
      ("required", "Int", "required expects Option"),
      ("skip, dive", "String", "unknown or invalid garde rule"),
      ("custom_with(check)", "String", "custom_with requires context"),
      ("dive_with", "String", "dive_with requires context"),
      ("pattern(\"[\")", "String", "invalid regular expression"),
      ("pattern(regex, extra)", "String", "pattern expects one quoted"),
      ("when_with(condition, ascii)", "String", "when_with requires context"),
      ("when(condition)", "String", "expected at least one garde rule"),
      ("dive_with(missing)", "String", "expects the name of a sibling"),
      ("matches(\"value\")", "String", "matches expects one unqualified"),
      ("matches(missing)", "String", "unknown record field: missing"),
      (
        "matches(value)", "String", "matches cannot refer to the annotated field itself",
      ),
      (
        "inner(matches(value))", "Array[String]", "matches is only supported directly on record fields",
      ),
    ] {
    let source = "#model.garde\nstruct S {\n  #model.garde(\{attribute})\n  value : \{field_type}\n}\n"
    let result = Ok(@garde_codegen.generate_many([("rules.mbt", source)])) catch {
      @garde_codegen.GenerateError(message) => Err(message)
    }
    guard result is Err(message) else { fail("accepted \{attribute}") }
    assert_true(message.has_prefix("rules.mbt-3:"), msg=message)
    assert_true(message.contains(expected), msg=message)
  }
}

///|
test "reject invalid payload selectors and unattached enum attributes" {
  for
    (source, expected) in [
      (
        "#model.garde(field(index=\"0\", matches(other)))\nstruct S(String)", "matches is only supported directly on record fields",
      ),
      (
        "#model.garde(field(index=\"0\", skip), field(index=\"1\", ascii))\nstruct S(String)",
        "no payload field for selector index:1",
      ),
      (
        "#model.garde(field(index=\"0\", skip), field(index=\"0\", ascii))\nstruct S(String)",
        "repeated garde field selector: index:0",
      ),
      (
        "#model.garde\nenum E {\n  #model.garde(field(name=\"missing\", ascii))\n  Item\n}",
        "no payload field for selector name:missing",
      ),
      (
        "enum E {\n  #model.garde(skip)\n  Item(String)\n}", "variant #model.garde requires #model.garde on its enum",
      ),
      (
        "#model.garde(bounds(U, [Length]), allow_unvalidated)\nstruct S[T](T)", "unknown or repeated type parameter in bounds: U",
      ),
    ] {
    let result = Ok(@garde_codegen.generate_many([("payloads.mbt", source)])) catch {
      @garde_codegen.GenerateError(message) => Err(message)
    }
    guard result is Err(message) else { fail("accepted \{source}") }
    assert_true(message.has_prefix("payloads.mbt-"), msg=message)
    assert_true(message.contains(expected), msg=message)
  }
}

///|
test "reject an unmarked field unless the struct opts in" {
  let source = "#model.garde\nstruct S { value : Int }\n"
  let result = Ok(@garde_codegen.generate_many([("rules.mbt", source)])) catch {
    @garde_codegen.GenerateError(message) => Err(message)
  }
  guard result is Err(message) else { fail("accepted an unmarked field") }
  assert_true(message.contains("field needs a garde rule"), msg=message)
}
