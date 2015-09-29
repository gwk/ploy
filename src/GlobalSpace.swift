// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class GlobalSpace: Space {

  var spaces: [Space] = []
  
  init() {
    super.init(pathNames: [], parent: nil)
    bindings["GLOBAL"] = ScopeRecord(sym: nil, hostName: "GLOBAL", isFwd: false, kind: .Space(self))
    for t in intrinsicTypes {
      bindings[t.description] = ScopeRecord(sym: nil, hostName: t.description, isFwd: false, kind: .Type(t))
    }
  }
  
  func getOrCreateSpace(syms: [Sym]) -> Space {
    var space: Space = self
    for (i, sym) in syms.enumerate() {
      if let r = space.bindings[sym.name] {
        switch r.kind {
        case .Space(let next):
          space = next
        default: sym.failType("expected a space; found a \(r.kind.kindDesc)")
        }
      } else { // create.
        let next = Space(pathNames: syms[0...i].map { $0.name }, parent: self)
        spaces.append(next)
        space.bindings[sym.name] = ScopeRecord(sym: nil, hostName: space.hostPrefix + sym.hostName, isFwd: false, kind: .Space(next))
        space = next
      }
    }
    return space
  }

  func defineAllDefs(ins: [In]) {
    for i in ins {
      let space = getOrCreateSpace([i.sym])
      for def in i.defs {
        space.declare(def)
      }
    }
  }
}


let globalSpace = GlobalSpace()
