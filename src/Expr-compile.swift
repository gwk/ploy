// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  var needsLazyDef: Bool {

    switch self {
    case .fn, .hostVal, .litNum, .litStr: return false
    case .ann(let ann): return ann.expr.needsLazyDef
    case .paren(let paren): return paren.els.any { $0.needsLazyDef }
    default: return true
    }
  }


  func compile(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    let conversion = ctx.conversionFor(expr: self)
    if let conversion = conversion {
      em.str(depth, "(()=>{ let $C = // \(conversion)")
    }

    switch self {

    case .acc(let acc):
      em.str(depth, "(")
      acc.accessee.compile(ctx, em, depth + 1, isTail: false)
      em.str(depth + 1, acc.accessor.hostAccessor)
      em.append(")")

    case .ann(let ann):
      ann.expr.compile(ctx, em, depth, isTail: isTail)

    case .bind(let bind):
      em.str(depth, "let \(bind.place.sym.hostName) =")
      bind.val.compile(ctx, em, depth + 1, isTail: false)

    case .call(let call):
      call.callee.compile(ctx, em, depth, isTail: false)
      em.append("(")
      call.arg.compile(ctx, em, depth + 1, isTail: false)
      em.append(")")

    case .do_(let do_):
      em.str(depth, "(()=>{")
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
        dflt.expr.compile(ctx, em, depth + 1, isTail: isTail)
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
      let type = ctx.typeFor(expr: self)
      switch type.kind {

      case .cmpd(let fields):
        em.str(depth, "{")
        var argIndex = 0
        for field in fields {
          compileCmpdField(ctx, em, depth, paren: paren, field: field, argIndex: &argIndex)
        }
        if argIndex != fields.count {
          paren.failType("expected \(fields.count) arguments; received \(argIndex)")
        }
        em.append("}")

      default:
        if !paren.isScalarType {
          paren.failType("expected type: \(type); received a struct value.")
        }
        paren.els[0].compile(ctx, em, depth, isTail: isTail)
      }

    case .path(let path):
      compileSym(em, depth, scopeRecord: ctx.pathRecords[path]!, sym: path.syms.last!)

    case .reify:
      fatalError()

    case .sig:
      fatalError()

    case .sym(let sym):
      compileSym(em, depth, scopeRecord: ctx.symRecords[sym]!, sym: sym)
    }

    if let conversion = conversion {
      em.append(";")
      switch (conversion.orig.kind, conversion.conv.kind) {

      case (.cmpd(let origFields), .cmpd(let convFields)):
        em.str(depth, "return {")
        for (o, c) in zip(origFields, convFields) {
          em.append(" \(c.hostName): $C.\(o.hostName),")
        }
        em.append(" };")
        default: fatalError("impossible conversion: \(conversion)")
      }
      em.append("})()")
    }
  }
}


func compileSym(_ em: Emitter, _ depth: Int, scopeRecord: ScopeRecord, sym: Sym) {
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


func compileCmpdField(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, paren: Paren, field: TypeField, argIndex: inout Int) {
  if argIndex < paren.els.count {
    let arg = paren.els[argIndex]
    let val: Expr
    switch arg {

    case .bind(let bind):
      let argLabel = bind.place.sym.name
      if let label = field.label {
        if argLabel != label {
          bind.place.sym.failType("argument label does not match type field label `(label)`")
        }
      } else {
        bind.place.sym.failType("argument label does not match unlabeled type field")
      }
      val = bind.val

    default: val = arg
    }
    em.str(depth, " \(field.hostName):")
    val.compile(ctx, em, depth + 1, isTail: false)
    em.append(",")
    argIndex += 1
  } else { // TODO: support default arguments.
    paren.failType("missing argument for parameter")
  }
}
