// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: _Form, Expr, Stmt { // do block: `{…}`.
  let stmts: [Stmt]
  let expr: Expr?
  
  init(_ syn: Syn, stmts: [Stmt], expr: Expr?) {
    self.stmts = stmts
    self.expr = expr
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for s in stmts {
      s.writeTo(&target, depth + 1)
    }
    if let expr = expr {
      expr.writeTo(&target, depth + 1)
    }
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    if let expr = expr {
      return expr.typeForExpr(ctx, LocalScope(parent: scope, em: scope.em))
    } else {
      return typeVoid
    }
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, "(function(){")
    compileBody(ctx, LocalScope(parent: scope, em: em), depth + 1, isTail: isTail)
    em.append("})()")
  }

  // MARK: Stmt

  func typecheckStmt(ctx: TypeCtx, _ scope: LocalScope) {
    typeForExpr(ctx, scope)
  }

  func compileStmt(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int) {
    compileExpr(ctx, scope, depth, isTail: false)
  }

  // MARK: Body
  
  func compileBody(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    for stmt in stmts {
      stmt.compileStmt(ctx, scope, depth)
      em.append(";")
    }
    if let expr = expr {
      em.str(depth, "return (")
      expr.compileExpr(ctx, scope, depth, isTail: isTail)
      em.append(")")
    }
  }
}

