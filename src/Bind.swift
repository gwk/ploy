// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Expr { // value binding: `name=expr`.
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
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    sym.write(to: &stream, depth + 1)
    val.write(to: &stream, depth + 1)
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let exprType = val.typeForExpr(ctx, scope)
    scope.addRecord(sym: sym, kind: .val(exprType))
    ctx.trackExpr(self, type: typeVoid)
    return typeVoid
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    em.str(depth, "let \(sym.hostName) =")
    val.compileExpr(ctx, em, depth + 1, isTail: false)
  }
}

