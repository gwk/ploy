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

  func typecheckStmt(ctx: TypeCtx, _ scope: LocalScope) {
    fatalError()
  }
  
  func compileStmt(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int) {
    fatalError()
  }

  // MARK: Def

  func compileDef(ctx: TypeCtx, _ space: Space) -> ScopeRecord.Kind {
    // TODO.
    return .Type(Type.Struct(spacePathNames: space.pathNames, sym: sym))
  }
}

