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
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    accessor.writeTo(&target, depth + 1)
    accessee.writeTo(&target, depth + 1)
  }

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let accesseeType = accessee.typeForExpr(ctx, scope)
    return Type.Prop(accessor.propAccessor, type: accesseeType)
  }

  func compileExpr(ctx: TypeCtx, _ scope: LocalScope, _ depth: Int, isTail: Bool) {
    let em = scope.em
    em.str(depth, isTail ? "{v:" : "(")
    accessee.compileExpr(ctx, scope, depth + 1, isTail: false)
    accessor.compileAccess(em, depth + 1, accesseeType: ctx.typeForForm(accessee))
    em.append(isTail ? "}" : ")")
  }
}

