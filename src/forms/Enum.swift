// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Enum: _Form, Def, Stmt { // enum declaration: `enum E variants…;`.
  let sym: Sym
  let variants: [Par]

  init(_ syn: Syn, sym: Sym, variants: [Par]) {
    self.sym = sym
    self.variants = variants
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    for v in variants {
      v.writeTo(&target, depth + 1)
    }
  }
  
  func compileStmt(em: Emit, _ depth: Int, _ scope: Scope) {
    fatalError()
  }
  
  // MARK: Def

  func compileDef(em: Emit, _ scope: Scope) {
    compileStmt(em, 0, scope)
  }
  
  func scopeRecordKind(scope: Scope) -> ScopeRecord.Kind {
    return .Type(TypeDecl(sym: sym))
  }
}


