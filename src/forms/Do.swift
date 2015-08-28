// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: _Form, Expr { // do block: `{…}`.
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
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    em.str(depth, "(function(){")
    let ret = compileBody(em, depth + 1, scope.makeChild(), expType)
    em.append("})()")
    return ret
  }
  
  func compileBody(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    for stmt in stmts {
      stmt.compileStmt(em, depth, scope)
      em.append(";")
    }
    var ret: TypeVal = typeVoid
    if let expr = expr {
      em.str(depth, " return (")
      ret = expr.compileExpr(em, depth, scope, expType)
      em.append(")")
    } else if expType !== typeVoid {
      self.failType("expected type \(expType); body has no return expression.")
    }
    return ret
  }
}

