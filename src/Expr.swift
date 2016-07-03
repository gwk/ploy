// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

enum Expr: SubForm {

  case acc(Acc)
  case ann(Ann)
  case bind(Bind)
  case call(Call)
  case cmpd(Cmpd)
  case cmpdType(CmpdType)
  case do_(Do)
  case fn(Fn)
  case if_(If)
  case litNum(LitNum)
  case litStr(LitStr)
  case paren(Paren)
  case path(Path)
  case reify(Reify)
  case sig(Sig)
  case sym(Sym)
  
  init(form: Form, subj: String, exp: String) {
    if let form = form as? Acc            { self = .acc(form) }
    else if let form = form as? Ann       { self = .ann(form) }
    else if let form = form as? Bind      { self = .bind(form) }
    else if let form = form as? Call      { self = .call(form) }
    else if let form = form as? Cmpd      { self = .cmpd(form) }
    else if let form = form as? CmpdType  { self = .cmpdType(form) }
    else if let form = form as? Do        { self = .do_(form) }
    else if let form = form as? Fn        { self = .fn(form) }
    else if let form = form as? If        { self = .if_(form) }
    else if let form = form as? LitNum    { self = .litNum(form) }
    else if let form = form as? LitStr    { self = .litStr(form) }
    else if let form = form as? Paren     { self = .paren(form) }
    else if let form = form as? Path      { self = .path(form) }
    else if let form = form as? Reify     { self = .reify(form) }
    else if let form = form as? Sig       { self = .sig(form) }
    else if let form = form as? Sym       { self = .sym(form) }
    else {
      form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
    }
  }

  init(form: Form, subj: String) {
    self.init(form: form, subj: subj, exp: "expression")
  }
  
  var form: Form {
    switch self {
    case .acc(let acc): return acc
    case .ann(let ann): return ann
    case .bind(let bind): return bind
    case .call(let call): return call
    case .cmpd(let cmpd): return cmpd
    case .cmpdType(let cmpdType): return cmpdType
    case .do_(let do_): return do_
    case .fn(let fn): return fn
    case .if_(let if_): return if_
    case .litNum(let litNum): return litNum
    case .litStr(let litStr): return litStr
    case .paren(let paren): return paren
    case .path(let path): return path
    case .reify(let reify): return reify 
    case .sig(let sig): return sig
    case .sym(let sym): return sym
    }
  }


  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    switch self {

    case .acc(let acc):
      let accesseeType = acc.accessee.typeForExpr(ctx, scope)
      let type = Type.Prop(acc.accessor.propAccessor, type: accesseeType)
      ctx.trackExpr(self, type: type)
      return type

    case .ann(let ann):
      let _ = ann.expr.typeForExpr(ctx, scope)
      let type = ann.typeExpr.typeForTypeExpr(scope, "type annotation")
      ctx.trackExpr(self, type: type)
      ctx.constrain(ann.expr, expForm: ann.typeExpr.form, expType: type, "type annotation")
      return type

    case .bind(let bind):
      let exprType = bind.val.typeForExpr(ctx, scope)
      _ = scope.addRecord(sym: bind.sym, kind: .val(exprType))
      ctx.trackExpr(self, type: typeVoid)
      return typeVoid

    case .call(let call):
      let _ = call.callee.typeForExpr(ctx, scope)
      let _ = call.arg.typeForExpr(ctx, scope)
      let parType = ctx.addFreeType()
      let type = ctx.addFreeType()
      let sigType = Type.Sig(par: parType, ret: type)
      ctx.trackExpr(self, type: type)
      ctx.constrain(call.callee, expForm: call, expType: sigType, "callee")
      ctx.constrain(call.arg, expForm: call, expType: parType, "argument")
      return type

    case .cmpd(let cmpd):
      let pars = cmpd.args.enumerated().map { $1.typeParForArg(ctx, scope, index: $0) }
      let type = Type.Cmpd(pars)
      ctx.trackExpr(self, type: type)
      return type

    case .cmpdType(let cmpdType):
      cmpdType.failType("type compound cannot be used as an expression (temporary).")

    case .do_(let do_):
      for (i, expr) in do_.exprs.enumerated() {
        if i == do_.exprs.count - 1 { break }
        let _ = expr.typeForExpr(ctx, scope)
        ctx.constrain(expr, expForm: do_, expType: typeVoid, "statement")
      }
      let type: Type
      if let last = do_.exprs.last {
        type = last.typeForExpr(ctx, LocalScope(parent: scope))
      } else {
        type = typeVoid
      }
      ctx.trackExpr(self, type: type)
      return type

    case .fn(let fn):
      let type = TypeExpr.sig(fn.sig).typeForTypeExpr(scope, "signature")
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord("$", type: type.sigPar)
      fnScope.addValRecord("self", type: type)
      let do_ = Expr.do_(fn.body) // HACK
      let _ = do_.typeForExpr(ctx, fnScope)
      ctx.trackExpr(self, type: type)
      ctx.constrain(do_, expForm: fn, expType: type.sigRet, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid: ctx.addFreeType() // all cases must return same type.
      ctx.trackExpr(self, type: type)
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, typeHalt support, etc.
      for c in if_.cases {
        let cond = c.condition
        let cons = c.consequence
        let _ = cond.typeForExpr(ctx, scope)
        let _ = cons.typeForExpr(ctx, scope)
        ctx.constrain(cond, expForm: c, expType: typeBool, "if form condition")
        ctx.constrain(cons, expForm: if_, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        let _ = dflt.typeForExpr(ctx, scope)
        ctx.constrain(dflt, expForm: if_, expType: type, "if form default")
      }
      return type

    case .litNum:
      let type = typeInt
      ctx.trackExpr(self, type: type)
      return type

    case .litStr:
      let type = typeStr
      ctx.trackExpr(self, type: type)
      return type

    case .paren(let paren):
      let type = paren.expr.typeForExpr(ctx, scope)
      ctx.trackExpr(self, type: type)
      return type

    case .path(let path):
      let record = scope.record(path: path)
      let type = path.syms.last!.typeForExprRecord(scope.record(path: path))
      ctx.trackExpr(self, type: type)
      ctx.pathRecords[path] = record
      return type

    case .reify(let reify):
      reify.failType("type reification cannot be used as a value expression (temporary)")

    case .sig(let sig):
      sig.failType("type signature cannot be used as a value expression (temporary)")

    case .sym(let sym):
      let record = scope.record(sym: sym)
      let type = sym.typeForExprRecord(record)
      ctx.trackExpr(self, type: type)
      ctx.symRecords[sym] = record
      return type
    }
  }


  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    switch self {

    case .acc(let acc):
      em.str(depth, "(")
      acc.accessee.compileExpr(ctx, em, depth + 1, isTail: false)
      em.str(depth + 1, acc.accessor.hostAccessor)
      em.append(")")

    case .ann(let ann):
      ann.expr.compileExpr(ctx, em, depth, isTail: isTail)

    case .bind(let bind):
      em.str(depth, "let \(bind.sym.hostName) =")
      bind.val.compileExpr(ctx, em, depth + 1, isTail: false)

    case .call(let call):
      call.callee.compileExpr(ctx, em, depth + 1, isTail: false)
      em.str(depth, "(")
      call.arg.compileExpr(ctx, em, depth + 1, isTail: false)
      em.append(")")

    case .cmpd(let cmpd):
      let type = ctx.typeForExpr(self)
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
      do_.compileBody(ctx, em, depth + 1, isTail: isTail)
      em.append("})()")

    case .fn(let fn):
      em.str(depth,  "(function self($){")
      fn.body.compileBody(ctx, em, depth + 1, isTail: true)
      em.append("})")

    case .if_(let if_):
      em.str(depth, "(")
      for c in if_.cases {
        c.condition.compileExpr(ctx, em, depth + 1, isTail: false)
        em.append(" ?")
        c.consequence.compileExpr(ctx, em, depth + 1, isTail: isTail)
        em.append(" :")
      }
      if let dflt = if_.dflt {
        dflt.compileExpr(ctx, em, depth + 1, isTail: isTail)
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
      paren.expr.compileExpr(ctx, em, depth + 1, isTail: isTail)
      em.append(")")

    case .path(let path):
      path.syms.last!.compileSym(em, depth, ctx.pathRecords[path]!, isTail: isTail)

    case .reify:
      fatalError()
    
    case .sig:
      fatalError()

    case .sym(let sym):
      sym.compileSym(em, depth, ctx.symRecords[sym]!, isTail: isTail)
    }
  }
}

