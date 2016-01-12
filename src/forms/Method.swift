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
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    identifier.writeTo(&target, depth + 1)
    sig.writeTo(&target, depth + 1)
    body.writeTo(&target, depth + 1)
  }

  // MARK: Def

  var sym: Sym { fatalError() } // a method is not an independent definition; handled specially.

  func compileDef(space: Space) -> ScopeRecord.Kind {
    fatalError()
  }

  #if false
  func scopeRecordKind(space: Space) -> ScopeRecord.Kind {
    fatalError()
  }
  #endif

  // MARK: Method

  func methodSig(space: Space) -> Type {
    return sig.typeVal(space, "method signature")
  }

  func compileMethod(ctx: TypeCtx, space: Space, polyFnType: Type, sigType: Type, hostName: String) {
    let em = space.makeEm()
    let fnScope = LocalScope(parent: space, em: em)
    fnScope.addValRecord("$", type: sigType.sigPar)
    fnScope.addValRecord("self", type: polyFnType)
    em.str(0, "function \(hostName)__\(sigType.globalIndex)($){ // \(sigType)")
    em.str(1, "let self = \(hostName)")
    body.compileBody(ctx, 1, fnScope, sigType.sigRet, isTail: true)
    em.append("}")
  }
}
