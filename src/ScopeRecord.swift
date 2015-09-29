// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRecord {
  // types get masked by the variant names.
  typealias _Space = Space
  typealias _Type = Type

  enum Kind {
    case Lazy(_Type)
    case PolyFn(PolyFnRecord)
    case Space(_Space)
    case Type(_Type)
    case Val(_Type)
    
    var kindDesc: String {
      switch self {
      case Lazy:  return "lazy value"
      case PolyFn: return "polyfunction"
      case Space: return "namespace"
      case Type:  return "type"
      case Val:   return "value"
      }
    }
  }
  
  let sym: Sym?
  let hostName: String
  let isFwd: Bool
  let kind: Kind
  
  init(sym: Sym?, hostName: String, isFwd: Bool, kind: Kind) {
    self.sym = sym
    self.hostName = hostName
    self.isFwd = isFwd
    self.kind = kind
  }
}
