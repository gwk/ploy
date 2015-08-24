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
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    em.str(depth, "(function(){")
    for stmt in stmts {
      stmt.compile(em, depth + 1, scope, typeVoid)
      em.append(";")
    }
    var ret: TypeVal = typeVoid
    if let expr = expr {
      em.str(depth + 1, "return (")
      ret = expr.compile(em, depth + 1, scope, expType)
    } else if expType != typeVoid {
      self.failType("expected type \(expType); body has no return expression.")
    }
    em.append(")})()")
    return ret
  }
}

