// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: _Form { // do block: `{…}`.
  let exprs: [Expr]

  init(_ syn: Syn, exprs: [Expr]) {
    self.exprs = exprs
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, exprs.isEmpty ? " {}\n" : "\n")
    for e in exprs {
      e.form.write(to: &stream, depth + 1)
    }
  }

  // MARK: Body
  
  func compileBody(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    for (i, expr) in exprs.enumerated() {
      let isLast = (i == exprs.lastIndex)
      if isLast {
        em.str(depth, "return (")
      }
      expr.compileExpr(ctx, em, depth, isTail: isLast && isTail)
      em.append(isLast ? ")" : ";")
    }
  }
}

