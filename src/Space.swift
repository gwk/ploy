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
        let name = sym.name
        let pathNames = identifierSyms[0...i].map { $0.name }
        space = Space(pathNames: pathNames, parent: self, file: file) // ROOT is always the parent of any named space.
        let record = ScopeRecord(name: name, hostName: space.hostPrefix + sym.hostName, sym: nil, kind: .space(space))
        // note: sym is nil because `in` forms can be declared in multiple locations.
        bindings.insertNew(name, value: record)
      }
    }
    return space
  }

  func add(defs defsList: [Def], root: Space) {
    for def in defsList {
      switch def {

      case .in_(let in_):
        let space = root.getOrCreateSpace(identifierSyms: in_.identifier!.syms)
        space.add(defs: in_.defs, root: root)

      case .method(let method):
        let syms = method.identifier.syms
        let targetSpaceSyms = Array(syms[0..<(syms.count - 1)])
        let targetSpace = root.getOrCreateSpace(identifierSyms: targetSpaceSyms)
        let name = method.identifier.name
        let methodList = targetSpace.methods.getDefault(name)
        methodList.pairs.append((self, method))

      default:
        if let existing = defs[def.sym.name] {
          def.sym.failRedef(original: existing.sym)
        } else {
          defs[def.sym.name] = def
        }
      }
    }
  }
}
