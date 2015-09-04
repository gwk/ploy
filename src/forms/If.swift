// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: _Form, Expr, Stmt { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Expr?

  init(_ syn: Syn, cases: [Case], dflt: Expr?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    for c in cases {
      c.writeTo(&target, depth + 1)
    }
    if let dflt = dflt {
      dflt.writeTo(&target, depth + 1)
    }
  }
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal, isTail: Bool) -> TypeVal {
    em.str(depth, "(")
    for c in cases {
      c.condition.compileExpr(em, depth + 1, scope, typeBool, isTail: false)
      em.append(" ?")
      c.consequence.compileExpr(em, depth + 1, scope, expType, isTail: isTail)
      em.append(" :")
    }
    if let dflt = dflt {
      dflt.compileExpr(em, depth + 1, scope, expType, isTail: isTail)
    } else if expType !== typeVoid {
      failType("expected type \(expType); `if` has no default")
    } else {
      em.str(depth + 1, "undefined")
    }
    em.append(")")
    return expType
  }
  
  func compileStmt(em: Emit, _ depth: Int, _ scope: Scope) {
    compileExpr(em, depth, scope, typeAny, isTail: false)
  }
}

