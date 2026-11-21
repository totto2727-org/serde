///|
#model.serde
#model.garde
pub(all) struct Endpoint[T] {
  #model.serde(rename="endpointUrl")
  #model.garde(url)
  url : String
  #model.garde(ipv4)
  allowed_ip : String?
  #model.garde(phone_number)
  phone : String?
  #model.garde(length(min="1"))
  name : String
  #model.garde(skip)
  metadata : T
}

///|
#model.serde(encode_only)
#model.garde
pub(all) struct Tagged[T, U] {
  #model.garde(skip)
  tag : T
  #model.serde(skip)
  #model.garde(matches(original))
  repeated : U
  #model.serde(skip)
  #model.garde(skip)
  original : U
}
