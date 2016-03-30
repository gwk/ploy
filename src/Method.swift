// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Method: _Form, Def { // method definition.
  let identifier: Identifier
  let sig: Sig
  let body: Do
  
  init(_ syn: Syn, identifier: Identifier, sig: Sig, body: Do) {
    self.identifier = identifier
    self.sig = sig
    self.body = body
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    identifier.writeTo(&target, depth + 1)
    sig.writeTo(&target, depth + 1)
    body.writeTo(&target, depth + 1)
  }

  // MARK: Def

  var sym: Sym { fatalError("Method is not an independent definition; sym should never be called.") }

  func compileDef(space: Space) -> ScopeRecord.Kind {
    fatalError("Method is not an independent definition; compileDef should never be called.")
  }

  // MARK: Method

  func typeForMethodSig(space: Space) -> Type {
    return sig.typeForTypeExpr(space, "method")
  }

  func compileMethod(space: Space, polyFnType: Type, sigType: Type, hostName: String) {
    let fnScope = LocalScope(parent: space)
    let parType = sigType.sigPar
    let retType = sigType.sigRet
    fnScope.addValRecord("$", type: parType)
    fnScope.addValRecord("self", type: polyFnType)
    let ctx = TypeCtx()
    let bodyType = body.typeForExpr(ctx, fnScope)
    ctx.constrain(body, bodyType, to: sig.ret, retType, "method body")
    ctx.resolve()
    let em = Emitter(file: space.file)
    em.str(0, "function \(hostName)__\(sigType.globalIndex)($){ // \(sigType)")
    em.str(1, "let self = \(hostName)")
    body.compileBody(ctx, em, 1, isTail: true)
    em.append("}")
  }
}
