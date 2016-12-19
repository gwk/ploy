// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


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
      _ = scope.addRecord(sym: bind.place.sym, kind: .fwd)
      let exprType = bind.val.genTypeConstraints(ctx, scope)
      _ = scope.addRecord(sym: bind.place.sym, kind: .val(exprType))
      return typeVoid

    case .call(let call):
      let _ = call.callee.genTypeConstraints(ctx, scope)
      let _ = call.arg.genTypeConstraints(ctx, scope)
      let domType = ctx.addFreeType()
      let type = ctx.addFreeType()
      let sigType = Type.Sig(dom: domType, ret: type)
      ctx.constrain(call.callee, expType: sigType, "callee")
      ctx.constrain(call.arg, expType: domType, "argument")
      return type

    case .do_(let do_):
      return genTypeConstraintsBody(ctx, scope, body: do_.body)

    case .fn(let fn):
      let type = Expr.sig(fn.sig).type(scope, "signature")
      guard case .sig(let dom, let ret) = type.kind else { fatalError() }
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord(name: "$", type: dom)
      fnScope.addValRecord(name: "self", type: type)
      let bodyType = genTypeConstraintsBody(ctx, fnScope, body: fn.body)
      ctx.constrain(form: fn.body, type: bodyType, expType: ret, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid: ctx.addFreeType() // all cases must return same type.
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, typeHalt support, etc.
      for case_ in if_.cases {
        let cond = case_.condition
        let cons = case_.consequence
        let _ = cond.genTypeConstraints(ctx, scope)
        let _ = cons.genTypeConstraints(ctx, scope)
        ctx.constrain(cond, expType: typeBool, "if form condition")
        ctx.constrain(cons, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        let _ = dflt.expr.genTypeConstraints(ctx, scope)
        ctx.constrain(dflt.expr, expType: type, "if form default")
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
      if paren.isScalarValue {
        let type = paren.els[0].genTypeConstraints(ctx, scope)
        return type
      }
      let fields = paren.els.enumerated().map { $1.typeFieldForArg(ctx, scope, index: $0) }
      let type = Type.Cmpd(fields)
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

    case .paren(let paren):
      if paren.isScalarType {
        return paren.els[0].type(scope, subj)
      }
      return Type.Cmpd(paren.els.enumerated().map {
        (index, par) in
        return par.typeFieldForPar(scope, index: index)
      })

    case .path(let path):
      return scope.typeBinding(path: path, subj: subj)

    case .reify:
      fatalError()

    case .sig(let sig):
      return Type.Sig(dom: sig.dom.type(scope, "signature domain"), ret: sig.ret.type(scope, "signature return"))

    case .sym(let sym):
      return scope.typeBinding(sym: sym, subj: subj)

    default:
      form.failType("\(subj) expects a type; received \(form.syntaxName).")
    }
  }


  func typeFieldForArg(_ ctx: TypeCtx, _ scope: LocalScope, index: Int) -> TypeField {
    let val: Expr
    switch self {
      case .bind(let bind): val = bind.val
      default: val = self
    }
    return TypeField(index: index, label: argLabel, type: val.genTypeConstraints(ctx, scope))
  }


  func typeFieldForPar(_ scope: Scope, index: Int) -> TypeField {
      var label: String? = nil
      var type: Type

      switch self {
      case .ann(let ann):
        guard case .sym(let sym) = ann.expr else {
          ann.expr.form.failSyntax("annotated parameter requires a label symbol.")
        }
        label = sym.name
        type = ann.typeExpr.type(scope, "parameter annotated type")

      case .bind(let bind):
        switch bind.place {
        case .ann(let ann):
          guard case .sym(let sym) = ann.expr else {
            ann.expr.form.failSyntax("annotated default parameter requires a label symbol.")
          }
          label = sym.name
          type = ann.typeExpr.type(scope, "default parameter annotated type")
        case .sym(let sym):
          // TODO: for now assume the sym refers to a type. This is going to change.
          type = scope.typeBinding(sym: sym, subj: "default parameter type")
        }

      default:
        let typeExpr = Expr(form: form, subj: "parameter type")
        type = typeExpr.type(scope, "parameter type")
      }
      return TypeField(index: index, label: label, type: type)
  }
}


func genTypeConstraintsBody(_ ctx: TypeCtx, _ scope: LocalScope, body: Body) -> Type {
  for (i, expr) in body.exprs.enumerated() {
    if i == body.exprs.count - 1 { break }
    let _ = expr.genTypeConstraints(ctx, scope)
    ctx.constrain(expr, expType: typeVoid, "statement")
  }
  let type: Type
  if let last = body.exprs.last {
    type = last.genTypeConstraints(ctx, LocalScope(parent: scope))
  } else {
    type = typeVoid
  }
  return type
}
