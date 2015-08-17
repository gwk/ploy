// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: _Form, Expr { // function declaration: `fn type body…;`.
  let sig: TypeExpr
  let body: Do

  init(_ syn: Syn, sig: TypeExpr, body: Do) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sig.writeTo(&target, depth + 1)
    body.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
  }
}

