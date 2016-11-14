// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LocalScope: Scope {

  init(parent: Scope) {
    super.init(pathNames: [], parent: parent)
  }

  override func getRecordInFrame(sym: Sym) -> ScopeRecord? {
    return bindings[sym.name]
  }
}

