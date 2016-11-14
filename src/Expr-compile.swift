// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  var needsLazyDef: Bool {

    switch self {
    case .fn, .hostVal, .litNum, .litStr: return false
    case .ann(let ann): return ann.expr.needsLazyDef
    case .cmpd(let cmpd): return cmpd.args.any { $0.needsLazyDef }
    case .paren(let paren): return paren.expr.needsLazyDef
    default: return true
    }
  }


  func compile(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    switch self {

    case .acc(let acc):
      em.str(depth, "(")
      acc.accessee.compile(ctx, em, depth + 1, isTail: false)
      em.str(depth + 1, acc.accessor.hostAccessor)
      em.append(")")

    case .ann(let ann):
      ann.expr.compile(ctx, em, depth, isTail: isTail)

    case .bind(let bind):
      em.str(depth, "let \(bind.sym.hostName) =")
      bind.val.compile(ctx, em, depth + 1, isTail: false)

    case .call(let call):
      call.callee.compile(ctx, em, depth, isTail: false)
      em.append("(")
      call.arg.compile(ctx, em, depth + 1, isTail: false)
      em.append(")")

    case .cmpd(let cmpd):
      let type = ctx.typeFor(expr: self)
      em.str(depth, "{")
      switch type.kind {
      case .cmpd(let pars, _, _):
        var argIndex = 0
        for par in pars {
          cmpd.compilePar(ctx, em, depth, par: par, argIndex: &argIndex)
        }
        if argIndex != pars.count {
          cmpd.failType("expected \(pars.count) arguments; received \(argIndex)")
        }
      default:
        cmpd.failType("expected type: \(type); received compound value.")
      }
      em.append("}")

    case .cmpdType:
      fatalError()

    case .do_(let do_):
      em.str(depth, "(function(){")
      compileBody(ctx, em, depth + 1, body: do_.body, isTail: isTail)
      em.append("})()")

    case .fn(let fn):
      em.str(depth,  "(function self($){")
      compileBody(ctx, em, depth + 1, body: fn.body, isTail: isTail)
      em.append("})")

    case .hostVal(let hostVal):
      let type_desc = hostVal.typeExpr.form.syn.visStringInline
      em.append(" // \(type_desc).")
      em.str(0, hostVal.code.val)

    case .if_(let if_):
      em.str(depth, "(")
      for c in if_.cases {
        c.condition.compile(ctx, em, depth + 1, isTail: false)
        em.append(" ?")
        c.consequence.compile(ctx, em, depth + 1, isTail: isTail)
        em.append(" :")
      }
      if let dflt = if_.dflt {
        dflt.compile(ctx, em, depth + 1, isTail: isTail)
      } else {
        em.str(depth + 1, "undefined")
      }
      em.append(")")

    case .litNum(let litNum):
      em.str(depth, String(litNum.val)) // TODO: preserve written format for clarity?

    case .litStr(let litStr):
      var s = "\""
      for code in litStr.val.codes {
        switch code {
        case "\0":    s.append("\\0")
        case "\u{8}": s.append("\\b")
        case "\t":    s.append("\\t")
        case "\n":    s.append("\\n")
        case "\r":    s.append("\\r")
        case "\"":    s.append("\\\"")
        case "\\":    s.append("\\\\")
        default:
          if code < " " || code > "~" {
            s.append("\\u{\(Int(code.value).hex)}")
          } else {
            s.append(Character(code))
          }
        }
      }
      s.append(Character("\""))
      em.str(depth, s)

    case .paren(let paren):
      em.str(depth, "(")
      paren.expr.compile(ctx, em, depth + 1, isTail: isTail)
      em.append(")")

    case .path(let path):
      compileSym(em, depth, scopeRecord: ctx.pathRecords[path]!, sym: path.syms.last!, isTail: isTail)

    case .reify:
      fatalError()

    case .sig:
      fatalError()

    case .sym(let sym):
      compileSym(em, depth, scopeRecord: ctx.symRecords[sym]!, sym: sym, isTail: isTail)
    }
  }
}


func compileSym(_ em: Emitter, _ depth: Int, scopeRecord: ScopeRecord, sym: Sym, isTail: Bool) {
  switch scopeRecord.kind {
  case .val:
    em.str(depth, scopeRecord.hostName)
  case .lazy:
    let s = "\(scopeRecord.hostName)__acc()"
    em.str(depth, "\(s)")
  case .fwd: // should never be reached, because type checking should notice.
    sym.failType("INTERNAL ERROR: `\(sym.name)` refers to a forward declaration.")
  case .polyFn:
    em.str(depth, scopeRecord.hostName)
  case .space(_):
    sym.failType("INTERNAL ERROR: `\(sym.name)` refers to a namespace.") // TODO: eventually this will return a runtime namespace.
  case .type(_):
    sym.failType("INTERNAL ERROR: `\(sym.name)` refers to a type.") // TODO: eventually this will return a runtime type.
  }
}


func compileBody(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, body: Body, isTail: Bool) {
  for (i, expr) in body.exprs.enumerated() {
    let isLast = (i == body.exprs.lastIndex)
    if isLast {
      em.str(depth, "return (")
    }
    expr.compile(ctx, em, depth, isTail: isLast && isTail)
    em.append(isLast ? ")" : ";")
  }
}
