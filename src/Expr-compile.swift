// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func compile(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, exp: Type?, isTail: Bool) {
    let type = ctx.typeFor(expr: self)
    let exp = exp ?? type
    let conv = ctx.globalCtx.conversionFor(orig: type, cast: exp)
    if let conv = conv {
      em.str(indent, "(\(conv.hostName)(")
    }

    switch self {

    case .acc(let acc):
      em.str(indent, "(")
      acc.accessee.compile(ctx, em, indent + 2, exp: nil, isTail: false)
      em.str(indent + 2, acc.accessor.hostAccessor)
      em.append(")")

    case .and(let and):
      if and.terms.isEmpty {
        em.str(indent, "true")
      } else {
        em.str(indent, "(")
        var isRight = false
        for term in and.terms {
          if isRight { em.append(" &&") }
          term.compile(ctx, em, indent + 2, exp: typeBool, isTail: false)
          isRight = true
        }
        em.append(")")
      }

    case .or(let or):
      if or.terms.isEmpty {
        em.str(indent, "false")
      } else {
        em.str(indent, "(")
        var isRight = false
        for term in or.terms {
          if isRight { em.append(" ||") }
          term.compile(ctx, em, indent + 2, exp: typeBool, isTail: false)
          isRight = true
        }
        em.append(")")
      }

    case .ann(let ann):
      ann.expr.compile(ctx, em, indent, exp: type, isTail: isTail)

    case .bind(let bind):
      em.str(indent, "const \(bind.place.sym.hostName) =")
      var exp: Type? = nil
      if let annExpr = bind.place.ann?.typeExpr {
        exp = ctx.typeFor(expr: annExpr)
      }
      bind.val.compile(ctx, em, indent + 2, exp: exp, isTail: false)
      em.append(";")

    case .call(let call):
      let calleeType = ctx.typeFor(expr: call.callee)
      // note: we rely on the actual callee type being identical to the expected callee type.
      // this works because functions are currently never convertible,
      // implying that method selection should not in the future be made to rely on this mechanism.
      // from the callee we can extract the expected arg type.
      call.callee.compile(ctx, em, indent, exp: nil, isTail: false) // exp is ok for now because sigs are not convertible.
      em.append("(")
      call.arg.compile(ctx, em, indent + 2, exp: calleeType.sigDom, isTail: false)
      em.append(")")

    case .do_(let do_):
      em.str(indent, "(()=>{")
      compileBody(ctx, em, indent + 2, body: do_.body, type: type, isTail: isTail)
      em.append("})()")

    case .fn(let fn):
      em.str(indent,  "(function self($){")
      compileBody(ctx, em, indent + 2, body: fn.body, type: ctx.typeFor(expr: .sig(fn.sig)).sigRet, isTail: isTail)
      em.append("})")

    case .hostVal(let hostVal):
      em.str(0, hostVal.code.val) // zero indent so that multiline host code is indented as written.

    case .if_(let if_):
      em.str(indent, "(")
      for c in if_.cases {
        c.condition.compile(ctx, em, indent + 2, exp: typeBool, isTail: false)
        em.append(" ?")
        c.consequence.compile(ctx, em, indent + 2, exp: type, isTail: isTail)
        em.append(" :")
      }
      if let dflt = if_.dflt {
        dflt.expr.compile(ctx, em, indent + 2, exp: type, isTail: isTail)
      } else {
        em.str(indent + 2, "undefined")
      }
      em.append(")")

    case .intersection: fatalError()

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
            s.append("\\u{\(Int(code.value).hex())}")
          } else {
            s.append(Character(code))
          }
        }
      }
      s.append(Character("\""))
      em.str(indent, s)

    case .magic(let magic):
      em.str(indent, magic.code)

    case .match: fatalError()

    case .paren(let paren):
      if paren.isScalarValue {
        paren.els[0].compile(ctx, em, indent, exp: type, isTail: isTail)
      } else if type == typeNull {
        em.str(indent, "null")
      } else {
        guard case .struct_(let posFields, let labFields, let variants) = type.kind else { paren.fatal("expected struct type") }
        ctx.globalCtx.addConstructor(type: type)
        em.str(indent, "(new $C\(type.globalIndex)(") // bling: $C: constructor.
        var argIndex = 0
        for (i, fieldType) in posFields.enumerated() {
          compileStructPositionalField(ctx, em, indent, paren: paren, fieldType: fieldType, parIndex: i, argIndex: &argIndex)
        }
        for (i, field) in labFields.enumerated() {
          compileStructLabeledField(ctx, em, indent, paren: paren, field: field, parIndex: i, argIndex: &argIndex)
        }
        if !variants.isEmpty {
          assert(variants.count == 1)
          assert(argIndex == paren.els.lastIndex!)
          compileStructVariant(ctx, em, indent, expr: paren.els.last!, variant: variants[0])
        }
        em.append("))")
      }

    case .path(let path):
      compileSym(ctx, em, indent, sym: path.lastSym, type: type)

    case .reif(let reif):
      reif.abstract.expr.compile(ctx, em, indent, exp: exp, isTail: isTail)

    case .sig: fatalError()

    case .sym(let sym):
      compileSym(ctx, em, indent, sym: sym, type: type)

    case .tag(let tag): // simple morph constructor; no payload.
      // Note: output must match compileStructVariant.
      // TODO: alternatively, could be optimized to not emit a boxed value, which always contains nil.
      ctx.globalCtx.addConstructor(type: type)
      em.str(indent, "(new $C\(type.globalIndex)('\(tag.sym.hostName)', null))") // bling: $C: constructor.

    case .tagTest(let tagTest):
      em.str(indent, "( '\(tagTest.tag.sym.name)' ==")
      tagTest.expr.compile(ctx, em, indent + 2, exp: nil, isTail: false)
      em.append(".$v)") // bling: $v: variant tag.

    case .typeAlias:
      em.str(indent, "undefined")

    case .typeArgs: fatalError()

    case .typeRefine: fatalError()

    case .typeReq: fatalError()

    case .typeVarDecl: fatalError()

    case .union: fatalError()

    case .void:
      em.str(indent, "undefined")
    }

    if conv != nil {
      em.append("))")
    }
  }

  func compileSym(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, sym: Sym, type: Type) {
    let scopeRecord = ctx.symRecords[sym]!
    let code: String
    switch scopeRecord.kind {
    case .val:
      code = scopeRecord.hostName
    case .lazy:
      code = "\(scopeRecord.hostName)__acc()"
    case .fwd: // should never be reached, because type checking should notice.
      sym.fatal("`\(sym.name)` refers to a forward declaration.")
    case .poly(let polyRecord):
      code = compileMethod(ctx.globalCtx, sym: sym, inferred: type, polyRecord: polyRecord, hostName: scopeRecord.hostName,
        selected: ctx.typeCtx.selectedMethods[sym]!)
    case .space:
      sym.fatal("`\(sym.name)` refers to a namespace.") // TODO: eventually this will return a runtime namespace.
    case .type:
      sym.fatal("`\(sym.name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    em.str(indent, code, syn: sym.syn, frameName: "")
  }
}


func compileBody(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, body: Body, type: Type, isTail: Bool) {
  for stmt in body.stmts {
    stmt.compile(ctx, em, indent, exp: typeVoid, isTail: false)
    em.append(";")
  }
  let hasRet = (type != typeVoid)
  if hasRet {
    em.str(indent, "return (")
  }
  body.expr.compile(ctx, em, indent, exp: type, isTail: isTail)
  if hasRet {
    em.append(")")
  }
}


func compileStructPositionalField(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, paren: Paren, fieldType: Type, parIndex: Int, argIndex: inout Int) {
  if argIndex < paren.els.count {
    let arg = paren.els[argIndex]
    if case .bind = arg { arg.fatal("expected positional field; found bind.") }
    arg.compile(ctx, em, indent + 2, exp: fieldType, isTail: false)
    em.append(",")
    argIndex += 1
  } else { // TODO: support default arguments.
    paren.fatal("missing argument for parameter")
  }
}


func compileStructLabeledField(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, paren: Paren, field: TypeLabField, parIndex: Int, argIndex: inout Int) {
  if argIndex < paren.els.count {
    let arg = paren.els[argIndex]
    let val: Expr
    switch arg {
    case .bind(let bind):
      let argLabel = bind.place.sym.name
      if argLabel != field.label { bind.place.sym.fatal("argument label does not match type field label `\(field.label)`") }
      val = bind.val
    default: val = arg
    }
    val.compile(ctx, em, indent + 2, exp: field.type, isTail: false)
    em.append(",")
    argIndex += 1
  } else { // TODO: support default arguments.
    paren.fatal("missing argument for parameter")
  }
}


func compileStructVariant(_ ctx: DefCtx, _ em: Emitter, _ indent: Int, expr: Expr, variant: TypeVariant) {
  guard case .bind(let bind) = expr else { fatalError() } // TODO: support bare tag.
  guard case .tag(let tag) = bind.place else { fatalError() } // TODO: skip this and use variant.hostName.
  if tag.sym.name != variant.label {
    tag.sym.fatal("morph constructor label does not match type's variant label `\(variant.label)`")
  }
  em.str(indent + 1, "'\(tag.sym.hostName)',")
  bind.val.compile(ctx, em, indent + 2, exp: variant.type, isTail: false)
}
