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
    let type = val.typeForExpr(ctx, scope)
    scope.addRecord(sym, kind: .Val(type))
    ctx.putForm(self, scope: scope)
    return typeVoid
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, "let \(scope.hostPrefix)\(sym.hostName) =")
    val.compileExpr(ctx, scope, depth + 1, isTail: false)
  }

  // MARK: Def
  
  func compileDef(ctx: TypeCtx, _ space: Space) -> ScopeRecord.Kind {
    let em = space.makeEm()
    let fullName = "\(space.name)/\(sym.name)"
    let hostName = "\(space.hostPrefix)\(sym.hostName)"
    // TODO: decide if lazy def is necessary.
    em.str(0, "var \(hostName)__acc = function() {")
    em.str(0, " \(hostName)__acc = function() {")
    em.str(0, "  throw \"error: lazy value '\(fullName)' recursively referenced during initialization.\" };")
    em.str(0, " let val =")
    let ctx = TypeCtx()
    let scope = LocalScope(parent: space, em: em)
    let type = val.typeForExpr(ctx, scope)
    val.compileExpr(ctx, scope, 1, isTail: false)
    em.append(";")
    em.str(0, " \(hostName)__acc = function() { return val };")
    em.str(0, " return val; }")
    return .Lazy(type)
  }
}

