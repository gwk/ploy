// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


final class MethodList: DefaultInitializable {
  typealias Pair = (space: Space, method: Method)
  var pairs: [Pair] = []
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
      let ctx = TypeCtx()
      let type = ctx.addFreeType()
      addRecord(sym, kind: .Fwd(type)) // the fwd def serves as a marker to prevent recursion.
      return addRecord(sym, kind: def.compileDef(ctx, self))
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
      let space = getOrCreateSpace(i.identifier.syms)
      for def in i.defs {
        if let method = def as? Method {
          let syms = method.identifier.syms
          let targetSpaceSyms = Array(syms[0..<(syms.count - 1)])
          let targetSpace = getOrCreateSpace(targetSpaceSyms)
          let name = method.identifier.name
          let methodList = targetSpace.methods.getDefault(name)
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