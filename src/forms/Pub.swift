// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Pub: _Form, Def { // public modifier: `pub expr;`.
  let def: Def

  init(_ syn: Syn, def: Def) {
    self.def = def
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    def.writeTo(&target, depth + 1)
  }

  // MARK: Def

  var sym: Sym { return def.sym }
  
  func scopeRecordKind(scope: Scope) -> ScopeRecord.Kind {
    return def.scopeRecordKind(scope)
  }

  func compileDef(em: Emitter, _ scope: Scope) {
    fatalError()
  }
}

