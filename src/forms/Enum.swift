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

  // MARK: Stmt
  
  func typecheckStmt(ctx: TypeCtx, _ scope: LocalScope) {
    fatalError()
  }

  func compileStmt(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int) {
    fatalError()
  }
  
  // MARK: Def

  func compileDef(ctx: TypeCtx, _ space: Space) -> ScopeRecord.Kind {
    compileStmt(ctx, LocalScope(parent: space, em: space.makeEm()), 0)
    // TODO.
    return .Type(Type.Enum(spacePathNames: space.pathNames, sym: sym))
  }
}


