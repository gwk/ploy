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
}
