// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Method: Form { // method definition.
  let identifier: Identifier
  let sig: Sig
  let body: Body

  init(_ syn: Syn, identifier: Identifier, sig: Sig, body: Body) {
    self.identifier = identifier
    self.sig = sig
    self.body = body
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    identifier.write(to: &stream, depth + 1)
    sig.write(to: &stream, depth + 1)
    body.write(to: &stream, depth + 1)
  }

  // MARK: Method

  func typeForMethodSig(_ space: Space) -> Type {
    return Expr.sig(sig).type(space, "method")
  }

  func compileMethod(_ space: Space, polyFnType: Type, sigType: Type, hostName: String) {
    let sigTypeIndex = sigType.globalIndex
    guard case .sig(let send, let ret) = sigType.kind else { fatalError() }
    let fnScope = LocalScope(parent: space)
    fnScope.addValRecord(name: "$", type: send)
    fnScope.addValRecord(name: "self", type: polyFnType)
    let ctx = TypeCtx()
    let type = genTypeConstraintsBody(ctx, fnScope, body: body)
    ctx.constrain(form: body, type: type, expForm: sig.ret.form, expType: ret, "method body")
    ctx.resolve()
    let em = Emitter(file: space.file)
    em.str(0, "function \(hostName)__\(sigTypeIndex)($){ // \(sigType)")
    em.str(1, "let self = \(hostName)")
    compileBody(ctx, em, 1, body: body, isTail: true)
    em.append("}")
    em.flush()
  }
}
