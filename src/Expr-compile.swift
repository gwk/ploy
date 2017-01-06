// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func compile(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, isTail: Bool) {
    var type = ctx.typeFor(expr: self)
    let hasConv = type.hasConv
    if hasConv {
      ctx.globalCtx.addConversion(type)
      em.str(indent, "(\(type.hostConvName)(")
    }
    if case .conv(let orig, _) = type.kind { type = orig }

    switch self {

    case .acc(let acc):
      em.str(indent, "(")
      acc.accessee.compile(&ctx, em, indent + 2, isTail: false)
      em.str(indent + 2, acc.accessor.hostAccessor)
      em.append(")")

    case .ann(let ann):
      ann.expr.compile(&ctx, em, indent, isTail: isTail)

    case .bind(let bind):
      em.str(indent, "let \(bind.place.sym.hostName) =")
      bind.val.compile(&ctx, em, indent + 2, isTail: false)

    case .call(let call):
      call.callee.compile(&ctx, em, indent, isTail: false)
      em.append("(")
      call.arg.compile(&ctx, em, indent + 2, isTail: false)
      em.append(")")

    case .do_(let do_):
      em.str(indent, "(()=>{")
      compileBody(&ctx, em, indent + 2, body: do_.body, isTail: isTail)
      em.append("})()")

    case .fn(let fn):
      em.str(indent,  "(function self($){")
      compileBody(&ctx, em, indent + 2, body: fn.body, isTail: isTail)
      em.append("})")

    case .hostVal(let hostVal):
      em.str(0, hostVal.code.val) // zero indent so that multiline host code is indented as written.

    case .if_(let if_):
      em.str(indent, "(")
      for c in if_.cases {
        c.condition.compile(&ctx, em, indent + 2, isTail: false)
        em.append(" ?")
        c.consequence.compile(&ctx, em, indent + 2, isTail: isTail)
        em.append(" :")
      }
      if let dflt = if_.dflt {
        dflt.expr.compile(&ctx, em, indent + 2, isTail: isTail)
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
      switch type.kind {

      case .cmpd(let fields):
        em.str(indent, "{")
        var argIndex = 0
        for (i, field) in fields.enumerated() {
          compileCmpdField(&ctx, em, indent, paren: paren, field: field, parIndex: i, argIndex: &argIndex)
        }
        if argIndex != fields.count {
          paren.fatal("expected \(fields.count) arguments; received \(argIndex)")
        }
        em.append("}")

      default:
        if !paren.isScalarType {
          paren.failType("expected type: \(type); received a struct value.")
        }
        paren.els[0].compile(&ctx, em, indent, isTail: isTail)
      }

    case .path(let path):
      compileSym(&ctx, em, indent, sym: path.syms.last!, scopeRecord: ctx.pathRecords[path]!)

    case .reify:
      fatalError()

    case .sig:
      fatalError()

    case .sym(let sym):
      compileSym(&ctx, em, indent, sym: sym, scopeRecord: ctx.symRecords[sym]!)

    case .void:
      em.str(indent, "undefined")
    }

    if hasConv {
      em.append("))")
    }
  }

  func compileSym(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, sym: Sym, scopeRecord: ScopeRecord) {
    switch scopeRecord.kind {
    case .val:
      em.str(indent, scopeRecord.hostName)
    case .lazy:
      let s = "\(scopeRecord.hostName)__acc()"
      em.str(indent, "\(s)")
    case .fwd: // should never be reached, because type checking should notice.
      sym.fatal("`\(sym.name)` refers to a forward declaration.")
    case .poly(let polyType, let morphsToNeedsLazy):
      let type = ctx.typeFor(expr: self)
      switch type.kind {
      case .sub(let origType, let morphType):
        assert(origType == polyType)
        let needsLazy = morphsToNeedsLazy[morphType]!
        let lazySuffix = (needsLazy ? "__acc()" : "")
        em.str(indent, "\(scopeRecord.hostName)__\(morphType.globalIndex)\(lazySuffix)")
      default:
        let msg = (type == polyType) ? "did not resolve" : "usage resolved to non-subtype: \(type)"
        sym.fatal("`\(sym.name)` refers to a polytype: \(polyType); \(msg).")
      }
    case .space:
      sym.fatal("`\(sym.name)` refers to a namespace.") // TODO: eventually this will return a runtime namespace.
    case .type:
      sym.fatal("`\(sym.name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
  }
}


func compileBody(_ ctx: inout TypeCtx, _ em: Emitter, _ indent: Int, body: Body, isTail: Bool) {
  for stmt in body.stmts {
    stmt.compile(&ctx, em, indent, isTail: false)
    em.append(";")
  }
  let type = ctx.typeFor(expr: body.expr)
  let hasRet = (type != typeVoid)
  if hasRet {
    em.str(indent, "return (")
  }
  body.expr.compile(&ctx, em, indent, isTail: isTail)
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
          bind.place.sym.failType("argument label does not match type field label `(label)`")
        }
      } else {
        bind.place.sym.failType("argument label does not match unlabeled type field")
      }
      val = bind.val

    default: val = arg
    }
    em.str(indent + 1, "\(field.hostName(index: parIndex)):")
    val.compile(&ctx, em, indent + 2, isTail: false)
    em.append(",")
    argIndex += 1
  } else { // TODO: support default arguments.
    paren.failType("missing argument for parameter")
  }
}
