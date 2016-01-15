// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Enum: _Form, Def, Expr { // enum declaration: `enum E variants…;`.
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

  // MARK: Def

  func compileDef(ctx: TypeCtx, _ space: Space) -> ScopeRecord.Kind {
    compileExpr(ctx, LocalScope(parent: space, em: space.makeEm()), 0, isTail: false)
    // TODO.
    return .Type(Type.Enum(spacePathNames: space.pathNames, sym: sym))
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    fatalError()
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    fatalError()
  }
}


