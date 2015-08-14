// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class In: _Form, Form { // in statement: `in module-name statements…;`.
  let name: Sym
  let defs: [Def]
  init(_ syn: Syn, name: Sym, defs: [Def]) {
    self.name = name
    self.defs = defs
    super.init(syn)
  }
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
    for d in defs {
      d.writeTo(&target, depth + 1)
    }
  }
}


