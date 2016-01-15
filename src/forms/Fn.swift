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

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = sig.typeForTypeExpr(ctx, scope, "signature")
    let fnScope = LocalScope(parent: scope, em: scope.em)
    fnScope.addValRecord("$", type: type.sigPar)
    fnScope.addValRecord("self", type: type)
    return body.typeForExpr(ctx, fnScope)
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    let fnScope = LocalScope(parent: scope, em: em)
    let type = ctx.typeForForm(self)
    fnScope.addValRecord("$", type: type.sigPar)
    fnScope.addValRecord("self", type: type)
    em.str(depth, (isTail ? "{v:" : "") + "(function self($){")
    body.compileBody(ctx, fnScope, depth + 1, isTail: true)
    em.append("})" + (isTail ? "}" : ""))
  }
}
