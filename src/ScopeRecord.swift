// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


struct ScopeRecord {

  enum Kind {
    case fwd // TODO: is it possible distinguish between types and vals?
    case lazy(Type)
    case poly(PolyRecord)
    case space(Space)
    case type(Type)
    case val(Type)
  }

  let name: String
  let hostName: String
  let sym: Sym? // bindings intrinsic to the language are not associated with any source location.
  let kind: Kind

  init(name: String, hostName: String? = nil, sym: Sym?, kind: Kind) {
    self.name = name
    self.hostName = hostName ?? name
    self.sym = sym
    self.kind = kind
  }

  var kindDesc: String {
    switch kind {
    case .fwd: return "forward declaration"
    case .lazy: return "lazy value"
    case .poly: return "polyfunction"
    case .space: return "namespace"
    case .type: return "type"
    case .val: return "value"
    }
  }
}
