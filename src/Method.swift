// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Method: Form { // method definition.
  let identifier: Identifier
  let sig: Sig
  let body: Do
  
  init(_ syn: Syn, identifier: Identifier, sig: Sig, body: Do) {
    self.identifier = identifier
    self.sig = sig
    self.body = body
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    identifier.form.write(to: &stream, depth + 1)
    sig.write(to: &stream, depth + 1)
    body.write(to: &stream, depth + 1)
  }

  // MARK: Method

  func typeForMethodSig(_ space: Space) -> Type {
    return TypeExpr.sig(sig).typeForTypeExpr(space, "method")
  }

  func compileMethod(_ space: Space, polyFnType: Type, sigType: Type, hostName: String) {
    let fnScope = LocalScope(parent: space)
    let parType = sigType.sigPar
    let retType = sigType.sigRet
    fnScope.addValRecord("$", type: parType)
    fnScope.addValRecord("self", type: polyFnType)
    let ctx = TypeCtx()
    let do_ = Expr.do_(body) // TODO: temporary hack to expose typeForExpr method.
    let _ = do_.typeForExpr(ctx, fnScope)
    ctx.constrain(do_, expForm: sig.ret.form, expType: retType, "method body")
    ctx.resolve()
    let em = Emitter(file: space.file)
    em.str(0, "function \(hostName)__\(sigType.globalIndex)($){ // \(sigType)")
    em.str(1, "let self = \(hostName)")
    body.compileBody(ctx, em, 1, isTail: true)
    em.append("}")
    em.flush()
  }
}
