// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func genTypeConstraints(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let type = genTypeConstraintsDisp(ctx, scope)
    ctx.trackExpr(self, type: type)
    return type
  }

  func genTypeConstraintsDisp(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    switch self {

    case .acc(let acc):
      let accesseeType = acc.accessee.genTypeConstraints(ctx, scope)
      let type = Type.Prop(acc.accessor.propAccessor, type: accesseeType)
      return type

    case .ann(let ann):
      let _ = ann.expr.genTypeConstraints(ctx, scope)
      let type = ann.typeExpr.type(scope, "type annotation")
      ctx.constrain(ann.expr, expForm: ann.typeExpr.form, expType: type, "type annotation")
      return type

    case .bind(let bind):
      _ = scope.addRecord(sym: bind.sym, kind: .fwd)
      let exprType = bind.val.genTypeConstraints(ctx, scope)
      _ = scope.addRecord(sym: bind.sym, kind: .val(exprType))
      return typeVoid

    case .call(let call):
      let _ = call.callee.genTypeConstraints(ctx, scope)
      let _ = call.arg.genTypeConstraints(ctx, scope)
      let parType = ctx.addFreeType()
      let type = ctx.addFreeType()
      let sigType = Type.Sig(par: parType, ret: type)
      ctx.constrain(call.callee, expForm: call, expType: sigType, "callee")
      ctx.constrain(call.arg, expForm: call, expType: parType, "argument")
      return type

    case .cmpd(let cmpd):
      let pars = cmpd.args.enumerated().map { $1.typeParForArg(ctx, scope, index: $0) }
      let type = Type.Cmpd(pars)
      return type

    case .cmpdType(let cmpdType):
      cmpdType.failType("type compound cannot be used as an expression (temporary).")

    case .do_(let do_):
      return genTypeConstraintsBody(ctx, scope, body: do_.body)

    case .fn(let fn):
      let type = Expr.sig(fn.sig).type(scope, "signature")
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord(name: "$", type: type.sigPar)
      fnScope.addValRecord(name: "self", type: type)
      let bodyType = genTypeConstraintsBody(ctx, fnScope, body: fn.body)
      ctx.constrain(form: fn.body, type: bodyType, expForm: fn, expType: type.sigRet, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid: ctx.addFreeType() // all cases must return same type.
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, typeHalt support, etc.
      for c in if_.cases {
        let cond = c.condition
        let cons = c.consequence
        let _ = cond.genTypeConstraints(ctx, scope)
        let _ = cons.genTypeConstraints(ctx, scope)
        ctx.constrain(cond, expForm: c, expType: typeBool, "if form condition")
        ctx.constrain(cons, expForm: if_, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        let _ = dflt.expr.genTypeConstraints(ctx, scope)
        ctx.constrain(dflt.expr, expForm: if_, expType: type, "if form default")
      }
      return type

    case .hostVal(let hostVal):
      for dep in hostVal.deps {
        _ = scope.getRecord(identifier: dep)
      }
      let type = hostVal.typeExpr.type(scope, "host value declaration")
      return type

    case .litNum:
      let type = typeInt
      return type

    case .litStr:
      let type = typeStr
      return type

    case .paren(let paren):
      let type = paren.expr.genTypeConstraints(ctx, scope)
      return type

    case .path(let path):
      let record = scope.getRecord(path: path)
      let type = path.syms.last!.typeForExprRecord(scope.getRecord(path: path))
      ctx.pathRecords[path] = record
      return type

    case .reify(let reify):
      reify.failType("type reification cannot be used as a value expression (temporary)")

    case .sig(let sig):
      sig.failType("type signature cannot be used as a value expression (temporary)")

    case .sym(let sym):
      let record = scope.getRecord(sym: sym)
      let type = sym.typeForExprRecord(record)
      ctx.symRecords[sym] = record
      return type
    }
  }


  func type(_ scope: Scope, _ subj: String) -> Type {
    switch self {

    case .cmpdType(let cmpdType):
      return Type.Cmpd(cmpdType.pars.enumerated().map {
        (index, par) in
        return par.typeParForPar(scope, index: index)
      })

    case .path(let path):
      return scope.typeBinding(path: path, subj: subj)

    case .reify:
      fatalError()

    case .sig(let sig):
      return Type.Sig(par: sig.send.type(scope, "signature send"), ret: sig.ret.type(scope, "signature return"))

    case .sym(let sym):
      return scope.typeBinding(sym: sym, subj: subj)

    default:
      let suggest: String
      switch self {
        case .cmpd, .paren: suggest = " Did you mean `<...>`?"
        default: suggest = ""
      }
      form.failType("\(subj) expects a type; received \(form.syntaxName).\(suggest)")
    }
  }


  func typeParForArg(_ ctx: TypeCtx, _ scope: LocalScope, index: Int) -> TypePar {
    return TypePar(index: index, label: label, type: genTypeConstraints(ctx, scope))
  }


  func typeParForPar(_ scope: Scope, index: Int) -> TypePar {
      var label: Sym? = nil
      var type: Type

      switch self {
      case .ann(let ann):
        guard case .sym(let sym) = ann.expr else {
          ann.expr.form.failSyntax("annotated parameter requires a label symbol.")
        }
        label = sym
        type = ann.typeExpr.type(scope, "parameter annotated type")

      case .bind(let bind):
        switch bind.place {
        case .ann(let ann):
          guard case .sym(let sym) = ann.expr else {
            ann.expr.form.failSyntax("annotated default parameter requires a label symbol.")
          }
          label = sym
          type = ann.typeExpr.type(scope, "default parameter annotated type")
        case .sym(let sym):
          // TODO: for now assume the sym refers to a type. This is going to change.
          type = scope.typeBinding(sym: sym, subj: "default parameter type")
        }

      default:
        let typeExpr = Expr(form: form, subj: "parameter type")
        type = typeExpr.type(scope, "parameter type")
      }
      return TypePar(index: index, label: label, type: type)
  }
}


func genTypeConstraintsBody(_ ctx: TypeCtx, _ scope: LocalScope, body: Body) -> Type {
  for (i, expr) in body.exprs.enumerated() {
    if i == body.exprs.count - 1 { break }
    let _ = expr.genTypeConstraints(ctx, scope)
    ctx.constrain(expr, expForm: body, expType: typeVoid, "statement")
  }
  let type: Type
  if let last = body.exprs.last {
    type = last.genTypeConstraints(ctx, LocalScope(parent: scope))
  } else {
    type = typeVoid
  }
  return type
}
