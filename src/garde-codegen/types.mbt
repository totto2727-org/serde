///|
priv struct Settings {
  allow_unvalidated : Bool
  transparent : Bool
  codec : CodecMode
  context : String?
  bounds : Map[String, Array[String]]
  selectors : Map[String, Array[Rule]]
}

///|
priv enum CodecMode {
  Auto
  Enabled
  Disabled
}

///|
fn render_quantifiers(
  params : Array[String],
  bounds : Map[String, Array[String]],
  json_bounds~ : Array[String] = [],
) -> String {
  if params.is_empty() {
    return ""
  }
  let generics = params.map(param => {
    let traits = bounds[param].map(name => {
      if name == "Validate" || name == "Length" {
        "@garde.\{name}"
      } else {
        name
      }
    })
    if json_bounds.contains(param) {
      traits.push("ToJson")
    }
    if traits.is_empty() {
      param
    } else {
      "\{param} : \{traits.join(" + ")}"
    }
  })
  "[\{generics.join(", ")}]"
}

///|
fn field_rules(
  props : @list.List[@attribute.Prop],
  at : String,
) -> Array[Rule] raise GenerateError {
  if props is More(Expr(Ident({ qual: None, name: "skip", })), tail=Empty) {
    []
  } else {
    parse_rules(props, at)
  }
}

///|
fn selector(prop : @attribute.Prop, at : String) -> String raise GenerateError {
  match prop {
    Labeled("name", String(name)) => "name:" + name
    Labeled("index", String(raw)) => {
      let index = @string.parse_int(raw[:], radix=10) catch {
        _ =>
          raise GenerateError(
            "\{at}: field index must be a non-negative decimal integer",
          )
      }
      if index < 0 {
        fail(at, "field index must be a non-negative decimal integer")
      }
      "index:\{index}"
    }
    _ =>
      raise GenerateError(
        "\{at}: field expects index=\"0\" or name=\"label\" as its first argument",
      )
  }
}

///|
fn settings(
  props : @list.List[@attribute.Prop],
  at : String,
  params : Array[String],
  select_fields~ : Bool,
  variant~ : Bool = false,
) -> Settings raise GenerateError {
  let mut allow_unvalidated = false
  let mut transparent = false
  let mut codec = Auto
  let mut context = None
  let bounds = Map([])
  let selectors = Map([])
  for prop in props {
    match prop {
      Expr(Ident({ qual: None, name: "allow_unvalidated", })) if !allow_unvalidated =>
        allow_unvalidated = true
      Expr(Ident({ qual: None, name: "transparent", })) if !variant &&
        !transparent => transparent = true
      Expr(Ident({ qual: None, name: "codec", })) if !variant && codec is Auto =>
        codec = Enabled
      Expr(Ident({ qual: None, name: "validate_only", })) if !variant &&
        codec is Auto => codec = Disabled
      Labeled("context", Ident({ qual, name, })) if !variant && context is None =>
        context = Some(
          match qual {
            Some(pkg) => "@\{pkg}.\{name}"
            None => name
          },
        )
      Expr(
        Apply(
          { qual: None, name: "bounds", },
          More(
            Expr(Ident({ qual: None, name: param, })),
            tail=More(Expr(Array(traits)), tail=Empty),
          ),
        ),
      ) if !variant => {
        if !params.contains(param) || bounds.contains(param) {
          fail(at, "unknown or repeated type parameter in bounds: \{param}")
        }
        let traits = traits
          .to_array()
          .map(trait_ => {
            match trait_ {
              Ident(
                {
                  qual: None,
                  name: "Validate"
                  | "Length"
                  | "Eq"
                  | "Compare"
                  | "Show" as name,
                },
              ) => name
              _ =>
                raise GenerateError(
                  "\{at}: bounds supports Validate, Length, Eq, Compare, and Show",
                )
            }
          })
        for index, trait_ in traits {
          if traits[:index].contains(trait_) {
            fail(at, "repeated trait in bounds for \{param}")
          }
        }
        bounds[param] = traits
      }
      Expr(Apply({ qual: None, name: "field", }, More(key, tail=rules))) if select_fields => {
        let key = selector(key, at)
        if selectors.contains(key) {
          fail(at, "repeated garde field selector: \{key}")
        }
        selectors[key] = field_rules(rules, at)
      }
      _ => fail(at, "unknown, invalid, or repeated #model.garde option")
    }
  }
  { allow_unvalidated, transparent, codec, context, bounds, selectors, }
}

///|
priv struct Slot {
  label : String?
  ty : @syntax.Type
}

///|
fn slot_path(label : String?, index : Int32) -> (String, String) {
  match label {
    Some(name) => ("name:\{name}", "field(\"\{name}\")")
    None => ("index:\{index}", "index(\{index})")
  }
}

///|
fn emit_field(
  out : StringBuilder,
  ty : @syntax.Type,
  rules : Array[Rule],
  at : String,
  emitter : Emitter,
  expr : String,
  path : String,
  record~ : (String, @list.List[@syntax.FieldDecl])? = None,
) -> Unit raise GenerateError {
  if !rules.is_empty() {
    let p = emitter.prefix
    out.write_string("{\nlet \{p}value = \{expr}\nlet \{p}path = \{path}\n")
    emit_rules(out, ty, rules, at, emitter, record~)
    out.write_string("}\n")
  }
}

///|
fn record_body(
  fields : @list.List[@syntax.FieldDecl],
  opts : Settings,
  emitter : Emitter,
  at : String,
) -> String raise GenerateError {
  let out = StringBuilder()
  let p = emitter.prefix
  let mut validated = 0
  for field in fields {
    match options(field.attrs) {
      None if !opts.allow_unvalidated =>
        fail(
          Show::to_string(field.loc),
          "field needs a garde rule or #model.garde(skip)",
        )
      None => ()
      Some((at, props)) => {
        let name = field.name.label
        let rules = field_rules(props, at)
        if !rules.is_empty() {
          validated += 1
        }
        emit_field(
          out,
          field.ty,
          rules,
          at,
          emitter,
          "\{p}self.\{name}",
          if opts.transparent {
            "\{p}path"
          } else {
            "\{p}path.field(\"\{name}\")"
          },
          record=Some((name, fields)),
        )
      }
    }
  }
  if opts.transparent && validated != 1 {
    fail(at, "transparent requires exactly one validated field")
  }
  out.to_string()
}

///|
fn payload_arm(
  name : String,
  slots : Array[Slot],
  opts : Settings,
  at : String,
  emitter : Emitter,
  variant~ : Bool,
  inherited_allow~ : Bool = false,
) -> String? raise GenerateError {
  let p = emitter.prefix
  let body = StringBuilder()
  let patterns = []
  let used = Map([])
  let mut validated = 0
  for index, slot in slots {
    let (key, path) = slot_path(slot.label, index)
    let bindings = match opts.selectors.get(key) {
      Some(rules) => {
        used[key] = true
        if rules.is_empty() {
          "_"
        } else {
          validated += 1
          let binding = match slot.label {
            Some(label) => "\{p}field_\{label}"
            None if slots.length() == 1 => "\{p}inner"
            None => "\{p}item_\{index}"
          }
          let parent = if variant {
            "\{p}path.field(\"\{name}\")"
          } else {
            "\{p}path"
          }
          emit_field(
            body,
            slot.ty,
            rules,
            at,
            emitter,
            binding,
            if opts.transparent {
              parent
            } else {
              "\{parent}.\{path}"
            },
          )
          binding
        }
      }
      None if opts.allow_unvalidated || inherited_allow => "_"
      None =>
        raise GenerateError(
          "\{at}: \{name} payload \{key} needs a garde field rule or skip",
        )
    }
    patterns.push(
      match slot.label {
        Some(label) => "\{label}=\{bindings}"
        None => bindings
      },
    )
  }
  for key, _ in opts.selectors {
    if !used.contains(key) {
      fail(at, "no payload field for selector \{key} in \{name}")
    }
  }
  if opts.transparent && validated != 1 {
    fail(at, "transparent requires exactly one validated field")
  }
  let body = body.to_string()
  if body.is_empty() {
    None
  } else {
    Some("\{name}(\{patterns.join(", ")}) => {\n\{body}}\n")
  }
}

///|
fn enum_body(
  variants : @list.List[@syntax.ConstrDecl],
  opts : Settings,
  emitter : Emitter,
) -> String raise GenerateError {
  let arms = StringBuilder()
  let mut fallback = false
  for variant in variants {
    let name = variant.name.name
    let (at, props) = options(variant.attrs).unwrap_or(
      (Show::to_string(variant.loc), @list.List([])),
    )
    let slots : Array[Slot] = variant.args
      .unwrap_or(@list.List([]))
      .to_array()
      .map(arg => { label: arg.label.map(label => label.name), ty: arg.ty, })
    let arm = if props
      is More(Expr(Ident({ qual: None, name: "skip", })), tail=Empty) {
      None
    } else {
      let variant_opts = settings(
        props,
        at,
        [],
        select_fields=true,
        variant=true,
      )
      payload_arm(
        name,
        slots,
        variant_opts,
        at,
        emitter,
        variant=true,
        inherited_allow=opts.allow_unvalidated,
      )
    }
    match arm {
      Some(code) => arms.write_string(code)
      None => fallback = true
    }
  }
  match arms.to_string() {
    "" => ""
    body => {
      let default_case = if fallback { "_ => ()\n" } else { "" }
      "match \{emitter.prefix}self {\n\{body}\{default_case}}\n"
    }
  }
}

///|
fn emit_declaration(
  out : StringBuilder,
  decl : @syntax.TypeDecl,
  seen : Map[String, String],
  p : String,
) -> Unit raise GenerateError {
  guard options(decl.attrs) is Some((at, props)) else {
    match decl.components {
      Record(fields~, ..) =>
        for field in fields {
          if options(field.attrs) is Some((at, _)) {
            fail(at, "field #model.garde requires #model.garde on its struct")
          }
        }
      Variant(variants) =>
        for variant in variants {
          if options(variant.attrs) is Some((at, _)) {
            fail(at, "variant #model.garde requires #model.garde on its enum")
          }
        }
      _ => ()
    }
    return
  }
  if seen.get(decl.tycon) is Some(first) {
    fail(
      at,
      "duplicate annotated type \{decl.tycon} (first defined at \{first})",
    )
  }
  seen[decl.tycon] = at
  let params = decl.params
    .to_array()
    .map(param => {
      guard param.name is Some(name) else {
        raise GenerateError(
          "\{param.loc}: #model.garde requires a named type parameter",
        )
      }
      name
    })
  let opts = settings(
    props,
    at,
    params,
    select_fields=decl.components is TupleStruct(_),
  )
  if opts.codec is Enabled {
    if !(decl.components is Record(..)) {
      fail(at, "garde codec requires a record struct")
    }
    if opts.context is Some(_) {
      fail(at, "garde codec does not support contextual validation")
    }
  }
  let bounds = Map([])
  for param in params {
    bounds[param] = opts.bounds.get(param).unwrap_or([])
  }
  let emitter = {
    prefix: p,
    context: opts.context,
    bounds,
    explicit_bounds: opts.bounds,
  }
  let body = match decl.components {
    Record(fields~, ..) => record_body(fields, opts, emitter, at)
    TupleStruct(types) => {
      let slots : Array[Slot] = types.to_array().map(ty => { label: None, ty, })
      match payload_arm(decl.tycon, slots, opts, at, emitter, variant=false) {
        Some(arm) => "match \{p}self {\n\{arm}}\n"
        None => ""
      }
    }
    Variant(variants) => {
      if opts.transparent {
        fail(at, "transparent is only supported on structs")
      }
      enum_body(variants, opts, emitter)
    }
    _ =>
      raise GenerateError(
        "\{at}: #model.garde supports record structs, tuple structs, and enums",
      )
  }
  let quantifiers = render_quantifiers(params, bounds)
  let name = decl.tycon
  let target = if params.is_empty() {
    name
  } else {
    "\{name}[\{params.join(", ")}]"
  }
  let visibility = if decl.type_vis is Priv(..) { "" } else { "pub " }
  let (self, report, path) = if body.is_empty() {
    ("_", "_", "_")
  } else {
    (p + "self", p + "report", p + "path")
  }
  match opts.context {
    None => {
      out.write_string(
        "\{visibility}impl\{quantifiers} @garde.Validate for \{target} with fn collect(\{self}, \{report}, \{path}) {\n\{body}}\n",
      )
      if !visibility.is_empty() {
        out.write_string(
          "pub extend \{name} with @garde.Validate::{validate}\n",
        )
      }
    }
    Some(ctx) => {
      let context = if body.contains(p + "context") {
        p + "context"
      } else {
        "_"
      }
      out.write_string(
        "\{visibility}fn\{quantifiers} \{name}::collect_with(\{self} : \{target}, \{context} : \{ctx}, \{report} : @garde.Report, \{path} : @garde.Path) -> Unit {\n\{body}}\n",
      )
      out.write_string(
        "\{visibility}fn\{quantifiers} \{name}::validate_with(self : \{target}, context : \{ctx}) -> Result[Unit, @garde.Report] {\n@garde.validate_using(self, (value, report, path) => value.collect_with(context, report, path))\n}\n",
      )
    }
  }
  if decl.components is Record(fields~, ..) {
    let json_bounds = if visibility.is_empty() {
      None
    } else {
      @serde_codegen.record_to_json_bounds(decl) catch {
        @serde_codegen.GenerateError(message) => raise GenerateError(message)
      }
    }
    if json_bounds is Some(_) {
      out.write_string("pub extend \{name} with ToJson::{to_json}\n")
    }
    if !(opts.codec is Disabled) && opts.context is None {
      emit_conversion(
        out,
        decl,
        fields,
        visibility,
        quantifiers,
        json_bounds.map(json_bounds => {
          render_quantifiers(params, bounds, json_bounds~)
        }),
        target,
        p,
      )
    }
  }
}
