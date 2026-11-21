///|
#serde.derive(Serialize, Deserialize)
pub struct Request {
  #serde.rename("requestId")
  request_id : String
  version : Int32
  user : User
  project : Project
  metrics : Metrics
  payload : Payload
}

///|
#serde.derive(Serialize, Deserialize)
pub struct User {
  name : String
  active : Bool
  age : Int32
  score : Double
  metadata : Metadata
}

///|
#serde.derive(Serialize, Deserialize)
pub struct Metadata {
  tags : Array[String]
}

///|
#serde.derive(Serialize, Deserialize)
pub struct Project {
  id : String
  archived : Bool
}

///|
#serde.derive(Serialize, Deserialize)
pub struct Metrics {
  #serde.rename("latencyMs")
  latency_ms : Double
  attempts : Int32
}

///|
#serde.derive(Serialize, Deserialize)
pub struct Payload {
  title : String
}

///|
pub fn from_string(text : String) -> Request raise @serde.DeError {
  @serde_json.from_string(text)
}

///|
pub fn to_string(request : Request) -> String raise @serde.SerError {
  @serde_json.to_string(request)
}
