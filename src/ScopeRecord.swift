// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRecord {
  // types get masked by the variant names.
  typealias _Space = Space
  typealias _Type = Type

  enum Kind {
    case fwd(_Type) // TODO: distinguish between fwd types and fwd vals? is this even possible?
    case lazy(_Type)
    case polyFn(_Type)
    case space(_Space)
    case type(_Type)
    case val(_Type)
    
    var kindDesc: String {
      switch self {
      case fwd: return "forward declaration"
      case lazy: return "lazy value"
      case polyFn: return "polyfunction"
      case space: return "namespace"
      case type: return "type"
      case val: return "value"
      }
    }
  }
  
  let sym: Sym? // bindings intrinsic to the language are not associated with any source location.
  let hostName: String
  let kind: Kind
  
  init(sym: Sym?, hostName: String, kind: Kind) {
    self.sym = sym
    self.hostName = hostName
    self.kind = kind
  }
}
