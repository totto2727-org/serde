///|
#model.serde
#model.garde
pub(all) struct Address {
  #model.garde(length(equal="2"))
  code : String
}

///|
#model.serde
#model.garde
pub(all) struct Account {
  #model.serde(rename="displayName")
  #model.garde(length(min="3"), custom(garde_value))
  name : String
  #model.garde(range(min="-1", max="10"))
  level : Int32
  #model.garde(required, length(min="2"))
  contact : String?
  #model.garde(dive)
  address : Address?
  #model.garde(length(min="1"), inner(dive))
  locations : Array[Address]
  #model.garde(skip)
  notes : String
}

///|
fn garde_value(name : String) -> String? {
  if name == "x" {
    Some("name is reserved")
  } else {
    None
  }
}

///|
#model.garde(allow_unvalidated)
pub(all) struct Queue {
  #model.garde(inner(inner(required, range(min="0"))))
  batches : FixedArray[ReadOnlyArray[Int32?]]
  name : String
}

///|
#model.serde
#model.garde(field(index="0", ascii, alphanumeric, prefix("A")))
pub(all) struct Code(String)

///|
pub impl @garde.Length for Code with fn garde_length(self) {
  let Code(text) = self
  text.length()
}

///|
#model.serde
#model.garde(field(index="0", dive), field(index="1", required))
pub struct Pair(Code, String?)

///|
#model.serde
#model.garde
pub(all) struct Batch[T, U] {
  #model.garde(inner(dive))
  items : Array[T]
  #model.garde(skip)
  metadata : U
}

///|
#model.serde(tag="kind", content="data", rename_all="snake_case")
#model.garde
pub enum Entry[T] {
  Empty
  #model.garde(field(index="0", dive), field(index="1", skip))
  CodeEntry(T, Int32)
  #model.garde(field(name="label", contains("\""), suffix("\u0021")))
  Named(label~ : String)
  #model.garde(skip)
  Unchecked(String)
}

///|
#model.garde(field(index="0", length(min="2")))
pub(all) struct Sized[T](T)

///|
#model.garde(bounds(T, [Length]), field(index="0", dive))
pub(all) struct NestedSized[T](Sized[T])

///|
#model.garde(field(index="0", length(min="2"), dive))
pub(all) struct Measured[T](T)

///|
pub(all) struct Policy {
  max_count : Int32
}

///|
#model.serde
#model.garde(context=Policy)
pub(all) struct Allocation {
  #model.garde(range(min="0"), custom_with(check_count))
  count : Int32
}

///|
fn check_count(count : Int32, policy : Policy) -> String? {
  if count > policy.max_count {
    Some("exceeds quota")
  } else {
    None
  }
}

///|
#model.serde
#model.garde(context=Policy)
pub(all) struct Request {
  #model.garde(inner(dive_with))
  allocations : Array[Allocation]
}

///|
#model.serde
#model.garde
pub(all) struct Confirmation {
  #model.serde(rename="repeatedCode")
  #model.garde(matches(code))
  repeated : String?
  #model.garde(pattern("^ID-[0-9]+\\.$"))
  code : String?
}

///|
#model.garde
pub(all) struct Same[T] {
  #model.garde(matches(original))
  repeated : T
  #model.garde(skip)
  original : T
}

///|
#model.serde
#model.garde(validate_only)
pub(all) struct ContactDetails {
  #model.garde(email)
  email : String
  #model.garde(url)
  website : String
  #model.garde(inner(ip))
  addresses : Array[String]
  #model.garde(ipv4)
  v4 : String?
  #model.garde(ipv6)
  v6 : String?
  #model.garde(phone_number)
  phone : String?
}

///|
const MINIMUM_WIDE : Int64 = 9007199254740993L

///|
#model.garde(transparent, field(index="0", pattern(is_uppercase_code)))
pub(all) struct ProductCode(String)

///|
fn is_uppercase_code(value : String) -> Bool {
  value.has_prefix("SKU-")
}

///|
#model.garde
pub(all) struct OrderChecks {
  #model.garde(skip)
  strict : Bool
  #model.garde(when(is_strict, required, dive))
  product : ProductCode?
  #model.garde(range(min=MINIMUM_WIDE))
  quantity : Int64
  #model.garde(range(min="0.5", max="2.5"))
  multiplier : Double
  #model.garde(skip)
  policy : Policy
  #model.garde(inner(dive_with(policy)))
  allocations : Array[Allocation]
}

///|
fn is_strict(value : OrderChecks) -> Bool {
  value.strict
}

///|
#model.garde
pub(all) struct NumericRanges {
  #model.garde(range(min="9007199254740993", max="9007199254740994"))
  wide : Int64
  #model.garde(range(min="18446744073709551614", max="18446744073709551615"))
  unsigned : UInt64
  #model.garde(range(equal="1000000000000000000000000000001N"))
  huge : @bigint.BigInt
  #model.garde(range(min="1.00000002", max="1.00000001"))
  single : Float
  #model.garde(range(min="-0.125F", max="2_000.0"))
  double : Double
  #model.garde(range(min="0x10L", max="0x20"))
  base16 : Int32
}

///|
#model.garde
pub(all) struct ReversedRange {
  #model.garde(range(min="9007199254740993", max="9007199254740992"))
  wide : Int64
}
