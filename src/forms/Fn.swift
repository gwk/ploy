// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: _Form, Expr { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Do

  init(_ syn: Syn, sig: Sig, body: Do) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sig.writeTo(&target, depth + 1)
    body.writeTo(&target, depth + 1)
  }
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    let typeVal = sig.typeValSig(scope, "signature")
    if !expType.accepts(typeVal) {
      sig.failType("expects \(expType)")
    }
    let fnScope = scope.makeChild()
    fnScope.addValRec("$", typeVal: typeVal.par)
    fnScope.addValRec("self", typeVal: typeVal)
    em.str(depth, (isTail ? "{v:" : "") + "(function self($){")
    body.compileBody(em, depth + 1, fnScope, typeVal.ret, isTail: true)
    em.append("})" + (isTail ? "}" : ""))
    return typeVal
  }
}
