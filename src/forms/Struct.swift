// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Struct: _Form, Def, Stmt { // struct declaration: `struct S fields…;`.
  let sym: Sym
  let fields: [Par]
  
  init(_ syn: Syn, sym: Sym, fields: [Par]) {
    self.sym = sym
    self.fields = fields
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    for f in fields {
      f.writeTo(&target, depth + 1)
    }
  }

  func compileStmt(em: Emitter, _ depth: Int, _ scope: Scope) {
    fatalError()
  }

  // MARK: Def

  func compileDef(em: Emitter, _ scope: Scope) {
    fatalError()
  }
  
  func scopeRecordKind(scope: Scope) -> ScopeRecord.Kind {
    return .Type(TypeDecl(sym: sym))
  }
}

