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
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    accessor.write(to: &stream, depth + 1)
    accessee.write(to: &stream, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let accesseeType = accessee.typeForExpr(ctx, scope)
    let type = Type.Prop(accessor.propAccessor, type: accesseeType)
    ctx.trackExpr(self, type: type)
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "(")
    accessee.compileExpr(ctx, em, depth + 1, isTail: false)
    em.str(depth + 1, accessor.hostAccessor)
    em.append(")")
  }
}

