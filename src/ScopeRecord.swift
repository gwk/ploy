// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRecord {
  // types get masked by the variant names.
  typealias _Space = Space
  typealias _Type = Type

  enum Kind {
    case Fwd()
    case Lazy(_Type)
    case PolyFn(_Type)
    case Space(_Space)
    case Type(_Type)
    case Val(_Type)
    
    var kindDesc: String {
      switch self {
      case Fwd: return "forward"
      case Lazy: return "lazy value"
      case PolyFn: return "polyfunction"
      case Space: return "namespace"
      case Type: return "type"
      case Val: return "value"
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
