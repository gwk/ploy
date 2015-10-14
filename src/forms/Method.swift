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

  func scopeRecordKind(space: Space) -> ScopeRecord.Kind {
    fatalError()
  }

  // MARK: Method

  func compileMethod(space: Space, expType: Type, hostName: String) -> TypeSig {
    let em = space.makeEm()
    let type = sig.typeValSig(space, "signature")
    if !expType.accepts(type) {
      sig.failType("expects \(expType)")
    }
    let fnScope = LocalScope(parent: space, em: em)
    fnScope.addValRecord("$", type: type.par)
    fnScope.addValRecord("self", type: type)
    em.str(0, "let \(hostName) = function self($){")
    body.compileBody(1, fnScope, type.ret, isTail: true)
    em.append("})")
    return type
  }
}
