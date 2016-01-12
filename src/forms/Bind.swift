// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Stmt, Def { // value binding: `name=expr`.
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
  
  func compileStmt(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope) {
    let em = scope.em
    em.str(depth, "let \(scope.hostPrefix)\(sym.hostName) =")
    let type = val.compileExpr(ctx, depth + 1, scope, ctx.addFreeType(), isTail: false)
    scope.addRecord(sym, kind: .Val(type))
  }

  // MARK: Def
  
  #if false
  func scopeRecordKind(space: Space) -> ScopeRecord.Kind {
    if let ann = val as? Ann {
      return .Lazy(ann.typeExpr.typeVal(space, "type annnotation"))
    } else {
      val.failSyntax("definition requires explicit type annotation")
    }
  }
  #endif
  
  func compileDef(space: Space) -> ScopeRecord.Kind {
    let em = space.makeEm()
    let fullName = "\(space.name)/\(sym.name)"
    let hostName = "\(space.hostPrefix)\(sym.hostName)"
    // TODO: decide if lazy def is necessary.
    em.str(0, "var \(hostName)__acc = function() {")
    em.str(0, " \(hostName)__acc = function() {")
    em.str(0, "  throw \"error: lazy value '\(fullName)' recursively referenced during initialization.\" };")
    em.str(0, " let val =")
    let ctx = TypeCtx()
    let type = val.compileExpr(ctx, 1, LocalScope(parent: space, em: em), ctx.addFreeType(), isTail: false)
    em.append(";")
    em.str(0, " \(hostName)__acc = function() { return val };")
    em.str(0, " return val; }")
    return .Lazy(type)
  }
}

