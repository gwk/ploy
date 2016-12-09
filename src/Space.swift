// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


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

  override func getRecordInFrame(sym: Sym) -> ScopeRecord? {
    if let r = bindings[sym.name] {
      return r
    }
    if let def = defs[sym.name] {
      _ = addRecord(sym: sym, kind: .fwd)
      let kind = def.compileDef(self)
      return addRecord(sym: sym, kind: kind)
    }
    return nil
  }

  func extendRecord(record: ScopeRecord, method: Method) {
    switch record.kind {
    case .polyFn: break
    default: method.identifier.form.failType("definition is not extensible",
      notes: (record.sym, "definition is here"))
    }
  }

  func createSpace(pathNames: [String], name: String, hostName: String) -> Space {
    let space = Space(pathNames: pathNames, parent: self, file: file)
    let record = ScopeRecord(name: name, hostName: space.hostPrefix + hostName, sym: nil, kind: .space(space))
    bindings.insertNew(name, value: record)
    // note: sym is nil because in forms can be declared in multiple locations.
    return space
  }

  func getOrCreateSpace(identifierSyms: [Sym]) -> Space {
    var space: Space = self
    for (i, sym) in identifierSyms.enumerated() {
      if let r = space.bindings[sym.name] {
        switch r.kind {
        case .space(let next):
          space = next
        default: sym.failType("expected a space; found a \(r.kindDesc)")
        }
      } else {
        space = space.createSpace(pathNames: identifierSyms[0...i].map { $0.name }, name: sym.name, hostName: sym.hostName)
      }
    }
    return space
  }

  func add(defs defsList: [Def]) {

    for def in defsList {
      if case .method(let method) = def {
        let syms = method.identifier.syms
        let targetSpaceSyms = Array(syms[0..<(syms.count - 1)])
        let targetSpace = getOrCreateSpace(identifierSyms: targetSpaceSyms)
        let name = method.identifier.name
        let methodList = targetSpace.methods.getDefault(name)
        methodList.pairs.append((self, method))
      } else if let existing = defs[def.sym.name] {
        def.sym.failRedef(original: existing.sym)
      } else {
        defs[def.sym.name] = def
      }
    }
  }

  func setupRoot(ins: [In], mainIn: In) -> Space { // returns MAIN.
    bindings["ROOT"] = ScopeRecord(name: "ROOT", sym: nil, kind: .space(self))
    for t in intrinsicTypes {
      let rec = ScopeRecord(name: t.description, sym: nil, kind: .type(t))
      bindings[t.description] = rec
    }
    for in_ in ins {
      let space = getOrCreateSpace(identifierSyms: in_.identifier!.syms)
      space.add(defs: in_.defs)
    }
    let mainSpace = createSpace(pathNames: ["MAIN"], name: "MAIN", hostName: "MAIN")
    mainSpace.add(defs: mainIn.defs)
    return mainSpace
  }

  func compileMain(mainIn: In) {
    guard let def = defs["main"] else {
      mainIn.failForm(prefix: "error", msg: "`main` is not defined in MAIN")
    }
    let record = getRecordInFrame(sym: def.sym)!
    let em = Emitter(file: self.file)
    compileSym(em, 0, scopeRecord: record, sym: def.sym, isTail: true)
    em.flush()
  }
}
