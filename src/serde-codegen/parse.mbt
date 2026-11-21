///|
fn serde_error(context : String, message : String) -> Unit raise GenerateError {
  raise GenerateError("\{context}: \{message}")
}

///|
fn serde_options(
  attrs : @list.List[@attribute.Attribute],
  allowed : Array[String],
) -> Map[String, @attribute.Expr]? raise GenerateError {
  let mut result = None
  for attr in attrs {
    let props = match attr.parsed {
      Some(Ident({ qual: Some("model"), name: "serde", })) => @list.List([])
      Some(Apply({ qual: Some("model"), name: "serde", }, props)) => props
      None if attr.raw.strip_prefix("#model.serde") is Some(payload) &&
        payload.trim_start().has_prefix("(") =>
        raise GenerateError("\{attr.loc}: malformed #model.serde attribute")
      _ => continue
    }
    let context = Show::to_string(attr.loc)
    if result is Some(_) {
      serde_error(context, "repeated #model.serde attribute")
    }
    let options : Map[String, @attribute.Expr] = Map([])
    for prop in props {
      let (key, value) = match prop {
        Labeled(key, value) => (key, value)
        Expr(Ident({ qual: None, name, })) => (name, Bool(true))
        _ => raise GenerateError("\{context}: invalid #model.serde option")
      }
      if !allowed.contains(key) {
        serde_error(context, "unknown #model.serde option: \{key}")
      }
      if options.contains(key) {
        serde_error(context, "repeated #model.serde option: \{key}")
      }
      options[key] = value
    }
    result = Some(options)
  }
  result
}

///|
fn string_option(
  options : Map[String, @attribute.Expr],
  key : String,
  context : String,
) -> String? raise GenerateError {
  match options.get(key) {
    None => None
    Some(String(value)) => Some(decode_attribute_string(value, context))
    _ => raise GenerateError("\{context}: \{key} must be a string")
  }
}

///|
fn decode_attribute_string(
  lexeme : String,
  context : String,
) -> String raise GenerateError {
  // The official attribute AST stores the literal lexeme, not its decoded value.
  let quoted = "\"\{lexeme}\""
  let value = @json.parse(quoted[:]) catch {
    _ =>
      raise GenerateError(
        "\{context}: use JSON-compatible string escapes in #model.serde",
      )
  }
  match value {
    String(value) => value
    _ => raise GenerateError("\{context}: invalid #model.serde string literal")
  }
}

///|
fn flag_option(
  options : Map[String, @attribute.Expr],
  key : String,
  context : String,
) -> Bool raise GenerateError {
  match options.get(key) {
    None => false
    Some(Bool(value)) => value
    _ => raise GenerateError("\{context}: \{key} must be a flag or boolean")
  }
}

///|
fn rename_words(name : String) -> Array[String] {
  let chars = name.to_array()
  let words = []
  let word = StringBuilder()
  for i, ch in chars {
    if ch == '_' {
      if !word.is_empty() {
        words.push(word.to_string())
        word.reset()
      }
    } else {
      if i > 0 && ch >= 'A' && ch <= 'Z' && !word.is_empty() {
        let prev = chars[i - 1]
        let after = i + 1 < chars.length() &&
          chars[i + 1] >= 'a' &&
          chars[i + 1] <= 'z'
        if (prev < 'A' || prev > 'Z') || after {
          words.push(word.to_string())
          word.reset()
        }
      }
      word.write_char(ch)
    }
  }
  if !word.is_empty() {
    words.push(word.to_string())
  }
  words
}

///|
fn capitalize_word(word : String) -> String {
  let result = StringBuilder()
  for i, ch in word.to_array() {
    if i == 0 {
      result.write_string(ch.to_string().to_upper())
    } else {
      result.write_char(ch)
    }
  }
  result.to_string()
}

///|
fn rename_case(name : String, rule : String?) -> String {
  guard rule is Some(rule) else { return name }
  let words = rename_words(name).map(fn(word) { word.to_lower() })
  match rule {
    "lowercase" => name.to_lower()
    "UPPERCASE" => name.to_upper()
    "PascalCase" => words.map(capitalize_word).join("")
    "camelCase" =>
      words
      .mapi(fn(i, word) { if i == 0 { word } else { capitalize_word(word) } })
      .join("")
    "snake_case" => words.join("_")
    "SCREAMING_SNAKE_CASE" => words.join("_").to_upper()
    "kebab-case" => words.join("-")
    "SCREAMING-KEBAB-CASE" => words.join("-").to_upper()
    _ => name
  }
}

///|
fn validate_type(ty : @syntax.Type) -> Unit raise GenerateError {
  match ty {
    Name(tys~, ..) | Tuple(tys~, ..) =>
      for child in tys {
        validate_type(child)
      }
    Option(ty~, ..) => validate_type(ty)
    _ => raise GenerateError("\{ty.loc()}: unsupported serde field type")
  }
}

///|
fn option_depth(ty : @syntax.Type) -> Int32 {
  match ty {
    Option(ty~, ..) => 1 + option_depth(ty)
    Name(constr_id={ id: Ident(name="Option"), .. }, tys~, ..) if tys.length() ==
      1 =>
      match tys.head() {
        Some(inner) => 1 + option_depth(inner)
        None => 0
      }
    _ => 0
  }
}

///|
fn field_attributes() -> Array[String] {
  [
    "rename", "aliases", "default", "skip", "skip_serializing", "skip_deserializing",
    "skip_serializing_if", "path", "serialize_with", "deserialize_with", "codec",
    "flatten",
  ]
}

///|
fn hook_identifier(name : String) -> Bool {
  let chars = name.to_array()
  !chars.is_empty() &&
  chars[0] is ('a'..<='z' | 'A'..<='Z' | '_') &&
  chars.all(ch => ch is ('a'..<='z' | 'A'..<='Z' | '0'..<='9' | '_'))
}

///|
fn hook_target(
  value : String,
  key : String,
  context : String,
) -> (String?, String) raise GenerateError {
  let invalid = "\{key} must name a MoonBit function, type, or package"
  if value.strip_prefix("@") is Some(qualified) {
    let parts = qualified.split(".").map(part => part.to_owned()).collect()
    match parts {
      [pkg, name] if hook_identifier(pkg) && hook_identifier(name) =>
        (Some(pkg), name)
      _ => raise GenerateError("\{context}: \{invalid}")
    }
  } else if hook_identifier(value) {
    (None, value)
  } else {
    raise GenerateError("\{context}: \{invalid}")
  }
}

///|
fn parse_hook(
  value : String,
  key : String,
  context : String,
) -> Hook raise GenerateError {
  let parts = value.split("::").map(part => part.to_owned()).collect()
  match parts {
    [target] => {
      let (pkg, name) = hook_target(target, key, context)
      Function(pkg, name)
    }
    [target, method_name] if hook_identifier(method_name) => {
      let (pkg, name) = hook_target(target, key, context)
      Method(pkg, name, method_name)
    }
    _ =>
      raise GenerateError(
        "\{context}: \{key} must name a MoonBit function or method",
      )
  }
}

///|
fn field_hooks(
  options : Map[String, @attribute.Expr],
  context : String,
) -> (Hook?, Hook?) raise GenerateError {
  let serialize = string_option(options, "serialize_with", context)
  let deserialize = string_option(options, "deserialize_with", context)
  if string_option(options, "codec", context) is Some(value) {
    if serialize is Some(_) || deserialize is Some(_) {
      serde_error(
        context, "codec cannot be combined with serialize_with or deserialize_with",
      )
    }
    if value.strip_prefix("@") is Some(pkg) && hook_identifier(pkg.to_owned()) {
      (
        Some(Function(Some(pkg.to_owned()), "serialize")),
        Some(Function(Some(pkg.to_owned()), "deserialize")),
      )
    } else {
      let (pkg, name) = hook_target(value, "codec", context)
      (
        Some(Method(pkg, name, "serialize")),
        Some(Method(pkg, name, "deserialize")),
      )
    }
  } else {
    (
      match serialize {
        Some(v) => Some(parse_hook(v, "serialize_with", context))
        None => None
      },
      match deserialize {
        Some(v) => Some(parse_hook(v, "deserialize_with", context))
        None => None
      },
    )
  }
}

///|
fn parse_field(
  field : @syntax.FieldDecl,
  rename_all : String?,
) -> Field raise GenerateError {
  let name = field.name.label
  let context = Show::to_string(field.loc)
  let options = serde_options(field.attrs, field_attributes()).unwrap_or(
    Map([]),
  )
  let path = match options.get("path") {
    None => []
    Some(Array(items)) if !items.is_empty() => {
      if options.contains("rename") || options.contains("aliases") {
        serde_error(context, "path cannot be combined with rename or aliases")
      }
      let keys = []
      for item in items {
        match item {
          String(key) => keys.push(decode_attribute_string(key, context))
          _ =>
            serde_error(
              context, "path must be a non-empty array of string keys",
            )
        }
      }
      keys
    }
    _ =>
      raise GenerateError(
        "\{context}: path must be a non-empty array of string keys",
      )
  }
  let wire_name = string_option(options, "rename", context).unwrap_or(
    rename_case(name, rename_all),
  )
  let aliases = match options.get("aliases") {
    None => []
    Some(String(alternate)) => [decode_attribute_string(alternate, context)]
    Some(Array(items)) => {
      let aliases = []
      for item in items {
        match item {
          String(alternate) =>
            aliases.push(decode_attribute_string(alternate, context))
          _ => serde_error(context, "aliases array must contain only strings")
        }
      }
      aliases
    }
    _ =>
      raise GenerateError(
        "\{context}: aliases must be a string or an array of strings",
      )
  }
  let option_depth = option_depth(field.ty)
  let optional = option_depth > 0
  let flatten = flag_option(options, "flatten", context)
  let skip = flag_option(options, "skip", context)
  let skip_serializing = flag_option(options, "skip_serializing", context)
  let skip_deserializing = flag_option(options, "skip_deserializing", context)
  let (serialize_with, deserialize_with) = field_hooks(options, context)
  if flatten {
    if optional {
      serde_error(context, "flatten requires a non-optional field")
    }
    if [
        "rename", "aliases", "path", "default", "skip", "skip_serializing", "skip_deserializing",
        "skip_serializing_if", "codec", "serialize_with", "deserialize_with",
      ].any(key => options.contains(key)) {
      serde_error(
        context, "flatten cannot be combined with other field options",
      )
    }
  }
  if skip && (serialize_with is Some(_) || deserialize_with is Some(_)) {
    serde_error(context, "skip cannot be combined with codec hooks")
  }
  if skip_serializing && serialize_with is Some(_) {
    serde_error(
      context, "skip_serializing cannot be combined with a serialization hook",
    )
  }
  if skip_deserializing && deserialize_with is Some(_) {
    serde_error(
      context, "skip_deserializing cannot be combined with a deserialization hook",
    )
  }
  let (omit_none, skip_serializing_if) = match
    string_option(options, "skip_serializing_if", context) {
    None => (false, None)
    Some("Option::is_none") if optional => (true, None)
    Some("Option::is_none") =>
      raise GenerateError(
        "\{context}: skip_serializing_if only supports Option::is_none on an Option field",
      )
    Some(value) =>
      (false, Some(parse_hook(value, "skip_serializing_if", context)))
  }
  let (default, default_with) = match options.get("default") {
    Some(String(value)) =>
      (
        false,
        Some(
          parse_hook(
            decode_attribute_string(value, context),
            "default",
            context,
          ),
        ),
      )
    None => (false, None)
    Some(Bool(value)) => (value, None)
    _ => raise GenerateError("\{context}: default must be a flag or a string")
  }
  validate_type(field.ty)
  {
    name,
    label: Some(name),
    wire_name,
    aliases,
    path,
    ty: field.ty,
    optional,
    option_depth,
    default,
    default_with,
    skip,
    skip_serializing,
    skip_deserializing,
    omit_none,
    skip_serializing_if,
    flatten,
    serialize_with,
    deserialize_with,
  }
}

///|
fn assert_unique_keys(
  fields : Array[Field],
  context : String,
  reserved : String?,
) -> Unit raise GenerateError {
  let seen : Map[String, Bool] = Map([])
  if reserved is Some(key) {
    seen[key] = true
  }
  for field in fields {
    for key in [field.wire_name, ..field.aliases] {
      if seen.contains(key) {
        serde_error(context, "duplicate wire key: \{key}")
      }
      seen[key] = true
    }
  }
}

///|
fn assert_unique_paths(
  fields : Array[Field],
  context : String,
) -> Unit raise GenerateError {
  let seen : Array[Array[String]] = []
  for field in fields {
    let paths = if field.path.is_empty() {
      [[field.wire_name], ..field.aliases.map(key => [key])]
    } else {
      [field.path]
    }
    for path in paths {
      for previous in seen {
        let overlap = if path.length() < previous.length() {
          path.length()
        } else {
          previous.length()
        }
        let mut prefix = true
        for i in 0..<overlap {
          if path[i] != previous[i] {
            prefix = false
            break
          }
        }
        if prefix {
          if path.length() == 1 && previous.length() == 1 {
            serde_error(context, "duplicate wire key: \{path[0]}")
          }
          serde_error(
            context,
            "conflicting JSON field paths: \{@debug.to_string(path)} and \{@debug.to_string(previous)}",
          )
        }
      }
      seen.push(path)
    }
  }
}

///|
fn parse_variant(
  variant : @syntax.ConstrDecl,
  rename_all : String?,
  repr : Representation,
  decode_only : Bool,
) -> Variant raise GenerateError {
  let name = variant.name.name
  let context = Show::to_string(variant.loc)
  let options = serde_options(variant.attrs, ["rename"]).unwrap_or(Map([]))
  let wire_name = string_option(options, "rename", context).unwrap_or(
    rename_case(name, rename_all),
  )
  let fields : Array[Field] = []
  if variant.args is Some(args) {
    for arg in args {
      let label = arg.label.map(fn(label) { label.name })
      let field_name = label.unwrap_or(fields.length().to_string())
      let option_depth = option_depth(arg.ty)
      validate_type(arg.ty)
      fields.push({
        name: field_name,
        label,
        wire_name: field_name,
        aliases: [],
        path: [],
        ty: arg.ty,
        optional: option_depth > 0,
        option_depth,
        default: false,
        default_with: None,
        skip: false,
        skip_serializing: false,
        skip_deserializing: false,
        omit_none: false,
        skip_serializing_if: None,
        flatten: false,
        serialize_with: None,
        deserialize_with: None,
      })
    }
  }
  if !fields.is_empty() {
    let labeled = fields[0].label is Some(_)
    for field in fields {
      if (field.label is Some(_)) != labeled {
        serde_error(
          context, "mixed named and positional variant fields are unsupported",
        )
      }
    }
    match repr {
      Internal(tag) =>
        if labeled {
          assert_unique_keys(fields, context, Some(tag))
        } else if !decode_only || fields.length() != 1 || fields[0].optional {
          serde_error(
            context, "internally tagged positional variants require decode_only and one non-optional payload",
          )
        }
      _ => assert_unique_keys(fields, context, None)
    }
  }
  { name, wire_name, fields, }
}

///|
fn parse_definition(decl : @syntax.TypeDecl) -> Definition? raise GenerateError {
  let context = Show::to_string(decl.loc)
  let options = serde_options(decl.attrs, [
    "rename_all", "tag", "content", "untagged", "deny_unknown_fields", "decode_only",
    "encode_only",
  ])
  guard options is Some(options) else {
    match decl.components {
      Record(fields~, ..) =>
        for field in fields {
          if serde_options(field.attrs, field_attributes()) is Some(_) {
            serde_error(
              context, "field #model.serde requires #model.serde on its type",
            )
          }
        }
      Variant(variants) =>
        for variant in variants {
          if serde_options(variant.attrs, ["rename"]) is Some(_) {
            serde_error(
              context, "variant #model.serde requires #model.serde on its type",
            )
          }
        }
      _ => ()
    }
    return None
  }
  let params : Array[String] = []
  for param in decl.params {
    guard param.name is Some(param_name) else {
      raise GenerateError(
        "\{param.loc}: #model.serde requires a named type parameter",
      )
    }
    params.push(param_name)
  }
  let decode_only = flag_option(options, "decode_only", context)
  let encode_only = flag_option(options, "encode_only", context)
  if decode_only && encode_only {
    serde_error(context, "encode_only and decode_only are mutually exclusive")
  }
  for directive in decl.deriving {
    match directive.type_name.name {
      Ident(name="ToJson") | Dot(id="ToJson", ..) if decode_only => ()
      Ident(name="FromJson") | Dot(id="FromJson", ..) if encode_only => ()
      Ident(name="ToJson" | "FromJson") | Dot(id="ToJson" | "FromJson", ..) =>
        serde_error(
          context, "#model.serde conflicts with a JSON deriving directive",
        )
      _ => ()
    }
  }
  let name = decl.tycon
  let is_private = decl.type_vis is Priv(..)
  let rename_all = string_option(options, "rename_all", context)
  if rename_all is Some(rule) &&
    ![
      "lowercase", "UPPERCASE", "PascalCase", "camelCase", "snake_case", "SCREAMING_SNAKE_CASE",
      "kebab-case", "SCREAMING-KEBAB-CASE",
    ].contains(rule) {
    serde_error(context, "unsupported rename_all rule: \{rule}")
  }
  let deny_unknown_fields = flag_option(options, "deny_unknown_fields", context)
  match decl.components {
    Record(fields~, ..) => {
      if options.contains("tag") ||
        options.contains("content") ||
        options.contains("untagged") {
        serde_error(
          context, "enum representation options are not allowed on a struct",
        )
      }
      let parsed = []
      for field in fields {
        parsed.push(parse_field(field, rename_all))
      }
      let direct = parsed.filter(field => !field.flatten)
      if parsed.length() - direct.length() > 1 {
        serde_error(context, "only one flatten field is supported per record")
      }
      if parsed.length() != direct.length() && deny_unknown_fields {
        serde_error(
          context, "flatten cannot be combined with deny_unknown_fields",
        )
      }
      if direct.all(field => field.path.is_empty()) {
        assert_unique_keys(direct, context, None)
      } else {
        assert_unique_paths(direct, context)
      }
      Some(
        Record({
          name,
          params,
          fields: parsed,
          deny_unknown_fields,
          decode_only,
          encode_only,
          is_private,
        }),
      )
    }
    TupleStruct(types) => {
      for option, _ in options {
        if option != "decode_only" && option != "encode_only" {
          serde_error(context, "\{option} is not allowed on a tuple struct")
        }
      }
      let elements = []
      for ty in types {
        validate_type(ty)
        elements.push(ty)
      }
      Some(
        TupleStruct({
          name,
          params,
          elements,
          decode_only,
          encode_only,
          is_private,
        }),
      )
    }
    Variant(constructors) => {
      if options.contains("deny_unknown_fields") {
        serde_error(context, "deny_unknown_fields is only supported on structs")
      }
      let tag = string_option(options, "tag", context)
      let content = string_option(options, "content", context)
      let untagged = flag_option(options, "untagged", context)
      let repr = match (tag, content, untagged) {
        (None, None, false) => External
        (Some(tag), None, false) => Internal(tag)
        (Some(tag), Some(content), false) if tag != content =>
          Adjacent(tag, content)
        (None, None, true) => Untagged
        _ =>
          raise GenerateError(
            "\{context}: incompatible tag, content, or untagged options",
          )
      }
      let variants : Array[Variant] = []
      let seen : Map[String, Bool] = Map([])
      for constr in constructors {
        let variant = parse_variant(constr, rename_all, repr, decode_only)
        if seen.contains(variant.wire_name) {
          serde_error(context, "duplicate wire variant: \{variant.wire_name}")
        }
        seen[variant.wire_name] = true
        variants.push(variant)
      }
      if variants.is_empty() {
        serde_error(context, "empty serde enums are unsupported")
      }
      Some(
        Sum({
          name,
          params,
          variants,
          repr,
          decode_only,
          encode_only,
          is_private,
        }),
      )
    }
    _ =>
      raise GenerateError(
        "\{context}: #model.serde only supports structs and enums",
      )
  }
}

///|
/// Parse MoonBit source and validate the declarations marked by `#model.serde`.
pub fn parse(
  source : String,
  name~ : String = "<input>",
) -> Array[Definition] raise GenerateError {
  parse_located(source, name).map(pair => pair.0)
}

///|
fn parse_located(
  source : String,
  name : String,
) -> Array[(Definition, String)] raise GenerateError {
  let (items, reports) = @parser.parse_string(source, name~)
  if !reports.is_empty() {
    raise GenerateError(Show::to_string(reports[0]))
  }
  let definitions = []
  for item in items {
    if item is TopTypeDef(decl) && parse_definition(decl) is Some(definition) {
      definitions.push((definition, Show::to_string(decl.loc)))
    }
  }
  definitions
}
