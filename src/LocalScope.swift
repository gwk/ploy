// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LocalScope: Scope {

  init(parent: Scope) {
    super.init(pathNames: [], parent: parent)
  }

  override func getRecordInFrame(sym: Sym) -> ScopeRecord? {
    return bindings[sym.name]
  }


  func addRecord(sym: Sym, kind: ScopeRecord.Kind) -> ScopeRecord {
    return super._addRecord(sym: sym, kind: kind)
  }

  func addValRecord(name: String, type: Type) {
    assert(!bindings.contains(key: name))
    bindings[name] = ScopeRecord(name: name, sym: nil, kind: .val(type))
  }
}

