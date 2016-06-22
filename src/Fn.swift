// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Fn: _Form, Expr { // function declaration: `fn type body…;`.
  let sig: Sig
  let body: Do

  init(_ syn: Syn, sig: Sig, body: Do) {
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sig.write(to: &stream, depth + 1)
    body.write(to: &stream, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = sig.typeForTypeExpr(scope, "signature")
    let fnScope = LocalScope(parent: scope)
    fnScope.addValRecord("$", type: type.sigPar)
    fnScope.addValRecord("self", type: type)
    let _ = body.typeForExpr(ctx, fnScope)
    ctx.trackExpr(self, type: type)
    ctx.constrain(body, expForm: self, expType: type.sigRet, "function body")
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, (isTail ? "{v:" : "") + "(function self($){")
    body.compileBody(ctx, em, depth + 1, isTail: true)
    em.append("})" + (isTail ? "}" : ""))
  }
}
