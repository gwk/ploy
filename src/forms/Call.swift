// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Call : _Form, Expr, Stmt {
  let callee: Expr
  let arg: Expr
  
  init(_ syn: Syn, callee: Expr, arg: Expr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Call(Syn(l.syn, r.syn),
      callee: castForm(l, "call", "expression"),
      arg: castForm(r, "call", "expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    callee.writeTo(&target, depth + 1)
    arg.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    em.str(depth, "((")
    let fnType = callee.compile(em, depth + 1, scope, anySigReturning(expType)) as! TypeValSig
    em.append(")(")
    arg.compile(em, depth + 1, scope, fnType.par)
    em.append("))")
    return fnType.ret
  }
}


// function call implied by adjacency to Cmpd: `f(a b)`.
class CallAdj: Call {}
