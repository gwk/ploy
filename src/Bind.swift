// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Expr, Def { // value binding: `name=expr`.
  let sym: Sym
  let val: Expr
  
  init(_ syn: Syn, sym: Sym, val: Expr) {
    self.sym = sym
    self.val = val
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Bind(Syn(l.syn, r.syn),
      sym: castForm(l, "binding", "name symbol"),
      val: castForm(r, "binding", "value expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    val.writeTo(&target, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let exprType = val.typeForExpr(ctx, scope)
    scope.addRecord(sym, kind: .Val(exprType))
    ctx.trackExpr(self, type: typeVoid)
    return typeVoid
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "let \(sym.hostName) =")
    val.compileExpr(ctx, em, depth + 1, isTail: false)
  }

  // MARK: Def
  
  func compileDef(space: Space) -> ScopeRecord.Kind {
    let ctx = TypeCtx()
    let _ = val.typeForExpr(ctx, LocalScope(parent: space)) // initial root type is ignored.
    ctx.resolve()
    let type = ctx.typeForExpr(val)
    let needsLazy: Bool
    switch type.kind {
    case .Sig: needsLazy = false
    default: needsLazy = true
    }
    let em = Emitter(file: space.file)
    let fullName = "\(space.name)/\(sym.name)"
    let hostName = "\(space.hostPrefix)\(sym.hostName)"
    if needsLazy {
      em.str(0, "var \(hostName)__acc = function() {")
      em.str(0, " \(hostName)__acc = function() {")
      em.str(0, "  throw \"error: lazy value '\(fullName)' recursively referenced during initialization.\" };")
      em.str(0, " let val =")
      val.compileExpr(ctx, em, 1, isTail: false)
      em.append(";")
      em.str(0, " \(hostName)__acc = function() { return val };")
      em.str(0, " return val; }")
      em.flush()
      return .Lazy(type)
    } else {
      em.str(0, "let \(hostName) =")
      val.compileExpr(ctx, em, 1, isTail: false)
      em.append(";")
      em.flush()
      return .Val(type)
    }
  }
}

