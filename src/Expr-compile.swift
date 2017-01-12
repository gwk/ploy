// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func compile(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, exp: Type, isTail: Bool) {
    let type = ctx.typeFor(expr: self)
    let hasConv = (type != exp)
    if hasConv {
      let conv = Conversion(orig: type, cast: exp)
      ctx.globalCtx.addConversion(conv)
      em.str(indent, "(\(conv.hostName)(")
    }

    switch self {

    case .acc(let acc):
      em.str(indent, "(")
      acc.accessee.compile(&ctx, em, indent + 2, exp: ctx.typeFor(expr: acc.accessee), isTail: false)
      em.str(indent + 2, acc.accessor.hostAccessor)
      em.append(")")

    case .ann(let ann):
      ann.expr.compile(&ctx, em, indent, exp: type, isTail: isTail)

    case .bind(let bind):
      em.str(indent, "let \(bind.place.sym.hostName) =")
      let valTypeExpr = (bind.place.ann?.typeExpr).or(bind.val)
      bind.val.compile(&ctx, em, indent + 2, exp: ctx.typeFor(expr: valTypeExpr), isTail: false)

    case .call(let call):
      let calleeType = ctx.typeFor(expr: call.callee)
      // note: we rely on the actual callee type being identical to the expected callee type.
      // this works because functions are currently never convertible,
      // implying that polymorph selection should not in the future be made to rely on this mechanism.
      // from the callee we can extract the expected arg type.
      call.callee.compile(&ctx, em, indent, exp: calleeType, isTail: false) // exp is ok for now because sigs are not convertible.
      em.append("(")
      call.arg.compile(&ctx, em, indent + 2, exp: calleeType.sigDom, isTail: false)
      em.append(")")

    case .do_(let do_):
      em.str(indent, "(()=>{")
      compileBody(&ctx, em, indent + 2, body: do_.body, type: type, isTail: isTail)
      em.append("})()")

    case .fn(let fn):
      em.str(indent,  "(function self($){")
      compileBody(&ctx, em, indent + 2, body: fn.body, type: ctx.typeFor(expr: .sig(fn.sig)).sigRet, isTail: isTail)
      em.append("})")

    case .hostVal(let hostVal):
      em.str(0, hostVal.code.val) // zero indent so that multiline host code is indented as written.

    case .if_(let if_):
      em.str(indent, "(")
      for c in if_.cases {
        c.condition.compile(&ctx, em, indent + 2, exp: typeBool, isTail: false)
        em.append(" ?")
        c.consequence.compile(&ctx, em, indent + 2, exp: type, isTail: isTail)
        em.append(" :")
      }
      if let dflt = if_.dflt {
        dflt.expr.compile(&ctx, em, indent + 2, exp: type, isTail: isTail)
      } else {
        em.str(indent + 2, "undefined")
      }
      em.append(")")

    case .litNum(let litNum):
      em.str(indent, String(litNum.val)) // TODO: preserve written format for clarity?

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
      em.str(indent, s)

    case .paren(let paren):
      if paren.isScalarValue {
        paren.els[0].compile(&ctx, em, indent, exp: type, isTail: isTail)
      } else {
        guard case .cmpd(let fields) = type.kind else { paren.fatal("expected struct type") }
        em.str(indent, "{")
        var argIndex = 0
        for (i, field) in fields.enumerated() {
          compileCmpdField(&ctx, em, indent, paren: paren, field: field, parIndex: i, argIndex: &argIndex)
        }
        em.append("}")
      }

    case .path(let path):
      compileSym(&ctx, em, indent, sym: path.syms.last!, scopeRecord: ctx.pathRecords[path]!, type: type)

    case .reify:
      fatalError()

    case .sig:
      fatalError()

    case .sym(let sym):
      compileSym(&ctx, em, indent, sym: sym, scopeRecord: ctx.symRecords[sym]!, type: type)

    case .void:
      em.str(indent, "undefined")
    }

    if hasConv {
      em.append("))")
    }
  }

  func compileSym(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, sym: Sym, scopeRecord: ScopeRecord, type: Type) {
    switch scopeRecord.kind {
    case .val:
      em.str(indent, scopeRecord.hostName)
    case .lazy:
      let s = "\(scopeRecord.hostName)__acc()"
      em.str(indent, "\(s)")
    case .fwd: // should never be reached, because type checking should notice.
      sym.fatal("`\(sym.name)` refers to a forward declaration.")
    case .poly(_, let morphsToNeedsLazy):
      let needsLazy = morphsToNeedsLazy[type]!
      let lazySuffix = (needsLazy ? "__acc()" : "")
      em.str(indent, "\(scopeRecord.hostName)__\(type.globalIndex)\(lazySuffix)")
    case .space:
      sym.fatal("`\(sym.name)` refers to a namespace.") // TODO: eventually this will return a runtime namespace.
    case .type:
      sym.fatal("`\(sym.name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
  }
}


func compileBody(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, body: Body, type: Type, isTail: Bool) {
  for stmt in body.stmts {
    stmt.compile(&ctx, em, indent, exp: typeVoid, isTail: false)
    em.append(";")
  }
  let hasRet = (type != typeVoid)
  if hasRet {
    em.str(indent, "return (")
  }
  body.expr.compile(&ctx, em, indent, exp: type, isTail: isTail)
  if hasRet {
    em.append(")")
  }
}


func compileCmpdField(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, paren: Paren, field: TypeField, parIndex: Int, argIndex: inout Int) {
  if argIndex < paren.els.count {
    let arg = paren.els[argIndex]
    let val: Expr
    switch arg {

    case .bind(let bind):
      let argLabel = bind.place.sym.name
      if let label = field.label {
        if argLabel != label {
          bind.place.sym.failType("argument label does not match type field label `\(label)`")
        }
      } else {
        bind.place.sym.failType("argument label does not match unlabeled type field")
      }
      val = bind.val

    default: val = arg
    }
    em.str(indent + 1, "\(field.hostName(index: parIndex)):")
    val.compile(&ctx, em, indent + 2, exp: field.type, isTail: false)
    em.append(",")
    argIndex += 1
  } else { // TODO: support default arguments.
    paren.failType("missing argument for parameter")
  }
}
