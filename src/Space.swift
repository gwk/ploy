// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class MethodList {
  var pairs: [(space: Space, method: Method)] = []
}


class Space: Scope {

  let file: OutFile
  var defs: [String: Def] = [:]
  var methods: [String: MethodList] = [:]

  init(pathNames: [String], parent: Space?, file: OutFile) {
    self.file = file
    super.init(pathNames: pathNames, parent: parent)
  }

  override func getRecord(sym: Sym) -> ScopeRecord? {
    if let r = bindings[sym.name] {
      return r
    }
    if let def = defs[sym.name] {
      addRecord(sym, kind: .Fwd())
      return addRecord(sym, kind: def.compileDef(self))
    }
    return nil
  }

  func makeEm() -> Emitter { return Emitter(file: file) }

  func extendRecord(record: ScopeRecord, method: Method) {
    switch record.kind {
    case .PolyFn: break
    default: method.identifier.failType("definition is not extensible", notes: (record.sym, "definition is here"))
    }
  }

  func setupGlobal(ins: [In]) {

    func getOrCreateSpace(identifier: Identifier) -> Space {
      var space: Space = self
      let syms = identifier.syms
      for (i, sym) in syms.enumerate() {
        if let r = space.bindings[sym.name] {
          switch r.kind {
          case .Space(let next):
            space = next
          default: sym.failType("expected a space; found a \(r.kind.kindDesc)")
          }
        } else { // create.
          let next = Space(pathNames: syms[0...i].map { $0.name }, parent: self, file: file)
          space.bindings[sym.name] = ScopeRecord(sym: nil, hostName: space.hostPrefix + sym.hostName, kind: .Space(next))
          space = next
        }
      }
      return space
    }

    bindings["ROOT"] = ScopeRecord(sym: nil, hostName: "ROOT", kind: .Space(self))
    for t in intrinsicTypes {
      bindings[t.description] = ScopeRecord(sym: nil, hostName: t.description, kind: .Type(t))
    }
    for i in ins {
      let space = getOrCreateSpace(i.identifier)
      for def in i.defs {
        if let method = def as? Method {
          let targetSpace = getOrCreateSpace(method.identifier)
          let name = method.identifier.name
          let methodList = targetSpace.methods.getDefault(name, dflt: { MethodList() })
          methodList.pairs.append((space, method))
        } else if let existing = space.defs[def.sym.name] {
          def.sym.failRedef(existing.sym)
        } else {
          space.defs[def.sym.name] = def
        }
      }
    }
  }
  

}