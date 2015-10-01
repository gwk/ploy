// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LocalScope: Scope {
  let em: Emitter

  init(parent: Scope, em: Emitter) {
    self.em = em
    super.init(pathNames: [], parent: parent)
  }

  override func getRecord(sym: Sym) -> ScopeRecord? {
    return bindings[sym.name]
  }
}

