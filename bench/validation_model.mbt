///|
#model.serde
#model.garde(validate_only)
#derive(Eq, Debug)
struct ValidationGroup {
  #model.garde(length(min="1", max="24"))
  label : String
  #model.garde(length(min="1", max="8"), inner(dive))
  members : Array[ValidationMember]
}

///|
#model.serde
#model.garde(validate_only)
#derive(Eq, Debug)
struct ValidationMember {
  #model.garde(length(min="2", max="32"))
  name : String
  #model.garde(range(min="18", max="120"))
  age : Int32
}
