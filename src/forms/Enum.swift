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
  
  func compileStmt(depth: Int, _ scope: LocalScope) {
    fatalError()
  }
  
  // MARK: Def

  func compileDef(space: Space) -> ScopeRecord.Kind {
    compileStmt(0, LocalScope(parent: space, em: space.makeEm()))
    return .Type(TypeDecl(sym: sym))
  }
  
  func scopeRecordKind(space: Space) -> ScopeRecord.Kind {
    return .Type(TypeDecl(sym: sym))
  }
}


