// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalScope: Scope {

  var spaces: [Scope] = []
  
  init() {
    super.init(pathNames: [], parent: nil)
    bindings["GLOBAL"] = ScopeRec(sym: nil, hostName: "GLOBAL", isFwd: false, kind: .Space(self))
    for t in intrinsicTypes {
      bindings[t.description] = ScopeRec(sym: nil, hostName: t.description, isFwd: false, kind: .Type(t))
    }
  }
  
  func getOrCreateSpace(syms: [Sym]) -> Scope {
    var space: Scope = self
    for (i, sym) in syms.enumerate() {
      if let r = space.bindings[sym.name] {
        switch r.kind {
        case .Space(let next):
          space = next
        default: sym.failType("expected a space; found a \(r.kind.kindDesc)")
        }
      } else { // create.
        let next = Scope(pathNames: syms[0...i].map { $0.name }, parent: self)
        spaces.append(next)
        space.bindings[sym.name] = ScopeRec(sym: nil, hostName: space.hostPrefix + sym.hostName, isFwd: false, kind: .Space(next))
        space = next
      }
    }
    return space
  }
}


let global = GlobalScope()
