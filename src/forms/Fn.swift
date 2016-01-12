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
  
  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    let em = scope.em
    let type = sig.typeVal(scope, "signature")
    refine(ctx, exp: expType, act: type)
    let fnScope = LocalScope(parent: scope, em: em)
    fnScope.addValRecord("$", type: type.sigPar)
    fnScope.addValRecord("self", type: type)
    em.str(depth, (isTail ? "{v:" : "") + "(function self($){")
    body.compileBody(ctx, depth + 1, fnScope, type.sigRet, isTail: true)
    em.append("})" + (isTail ? "}" : ""))
    return type
  }
}
