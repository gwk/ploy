// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Struct: _Form, Expr { // struct declaration: `struct S fields…;`.
  let name: Sym
  let fields: [Par]
  init(_ syn: Syn, name: Sym, fields: [Par]) {
    self.name = name
    self.fields = fields
    super.init(syn)
  }
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    name.writeTo(&target, depth + 1)
    for f in fields {
      f.writeTo(&target, depth + 1)
    }
  }
}

