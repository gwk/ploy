// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Space: Scope {

  var defs: [String: Def] = [:]
  var methods: [String: [Method]] = [:]
  var usedDefs: [Def] = []

  func declare(def: Def) {
    if let method = def as? Method {
      fatalError("method definition not implemented: \(method)")
    } else if let existing = defs[def.sym.name] {
      def.sym.failRedef(existing.sym)
    } else {
      defs[def.sym.name] = def
    }
  }

  override func getRecord(sym: Sym) -> ScopeRecord? {
    if let r = super.getRecord(sym) {
      return r
    }
    if let def = defs[sym.name] {
      let r = addRecord(sym, isFwd: true, kind: def.scopeRecordKind(self))
      usedDefs.append(def)
      return r
    }
    return nil
  }

  func extendRecord(record: ScopeRecord, method: Method) {
    switch record.kind {
    case .PolyFn: break
    default: method.identifier.failType("definition is not extensible", notes: (record.sym, "definition is here"))
    }
  }

}