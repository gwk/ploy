// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Scoped: _Form, Expr { // local scope: `scoped body…;`.
  let body: Do
  
  init(_ syn: Syn, body: Do) {
    self.body = body
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    body.writeTo(&target, depth + 1)
  }

  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
  }
}

