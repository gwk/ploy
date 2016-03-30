// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Acc: _Form, Expr { // accessor: `field@val`.
  let accessor: Accessor
  let accessee: Expr
  
  init(_ syn: Syn, accessor: Accessor, accessee: Expr) {
    self.accessor = accessor
    self.accessee = accessee
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Acc(Syn(l.syn, r.syn),
      accessor: castForm(l, "access", "accessor symbol or number literal"),
      accessee: castForm(r, "access", "accessee expression"))
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    accessor.writeTo(&target, depth + 1)
    accessee.writeTo(&target, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let accesseeType = accessee.typeForExpr(ctx, scope)
    let type = Type.Prop(accessor.propAccessor, type: accesseeType)
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, isTail ? "{v:" : "(")
    accessee.compileExpr(ctx, em, depth + 1, isTail: false)
    accessor.compileAccess(em, depth + 1, accesseeType: ctx.typeForExpr(accessee))
    em.append(isTail ? "}" : ")")
  }
}

