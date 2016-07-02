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

  override func getRecord(sym: Sym) -> ScopeRecord? {
    if let r = bindings[sym.name] {
      return r
    }
    if let def = defs[sym.name] {
      return addRecord(sym: sym, kind: def.compileDef(self))
    }
    return nil
  }

  func compileMain(mainIn: In) -> ScopeRecord {
    guard let def = defs["main"] else {
      mainIn.failForm(prefix: "error", msg: "`main` is not defined in MAIN")
    }
    let record = getRecord(sym: def.sym)!
    guard case .val(let type) = record.kind else {
      def.form.failType("expected `main` to be a function value; found \(record.kind.kindDesc)")
    }
    if type != typeOfMainFn {
      def.form.failType("expected `main` to have type ()%Int; actual type is \(type)")
    }
    return record
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
    bindings.insertNew(name, value: ScopeRecord(sym: nil, hostName: space.hostPrefix + hostName, kind: .space(space)))
    // note: sym is nil because in forms can be declared in multiple locations.
    return space
  }

  func getOrCreateSpace(syms: [Sym]) -> Space {
    var space: Space = self
    for (i, sym) in syms.enumerated() {
      if let r = space.bindings[sym.name] {
        switch r.kind {
        case .space(let next):
          space = next
        default: sym.failType("expected a space; found a \(r.kind.kindDesc)")
        }
      } else {
        space = space.createSpace(pathNames: syms[0...i].map { $0.name }, name: sym.name, hostName: sym.hostName)
      }
    }
    return space
  }

  func add(defs defsList: [Def]) {

    for def in defsList {
      if case .method(let method) = def {
        let syms = method.identifier.syms
        let targetSpaceSyms = Array(syms[0..<(syms.count - 1)])
        let targetSpace = getOrCreateSpace(syms: targetSpaceSyms)
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
    bindings["ROOT"] = ScopeRecord(sym: nil, hostName: "ROOT", kind: .space(self))
    for t in intrinsicTypes {
      bindings[t.description] = ScopeRecord(sym: nil, hostName: t.description, kind: .type(t))
    }
    for i in ins {
      let space = getOrCreateSpace(syms: i.identifier!.syms)
      space.add(defs: i.defs)
    }
    let mainSpace = createSpace(pathNames: ["MAIN"], name: "MAIN", hostName: "MAIN")
    mainSpace.add(defs: mainIn.defs)
    return mainSpace
  }
  

}
