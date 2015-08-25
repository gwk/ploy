// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class In: _Form, Form { // in statement: `in module-name statements…;`.
  let sym: Sym
  let defs: [Def]

  init(_ syn: Syn, sym: Sym, defs: [Def]) {
    self.sym = sym
    self.defs = defs
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    for d in defs {
      d.writeTo(&target, depth + 1)
    }
  }
  
  func defineDefs(space: Scope) {
    for d in defs {
      if let existing = space.defs[d.sym.name] {
        sym.failRedef(existing.sym)
      }
      else {
        space.defs[d.sym.name] = d
      }
    }
  }
}


