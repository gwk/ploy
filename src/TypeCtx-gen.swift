// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension TypeCtx {

  mutating func genConstraints(_ scope: LocalScope, expr: Expr) -> Type {
    let type = genConstraintsDisp(scope, expr: expr)
    trackExpr(expr, type: type)
    return type
  }

  mutating func genConstraintsDisp(_ scope: LocalScope, expr: Expr) -> Type {
    switch expr {

    case .acc(let acc):
      let accesseeType = genConstraints(scope, expr: acc.accessee)
      return Type.Prop(acc.accessor.propAccessor, type: accesseeType)

    case .ann(let ann):
      _ = genConstraints(scope, expr: ann.expr)
      return addAnnConstraint(scope, expr: ann.expr, ann: ann)

    case .bind(let bind):
      _ = scope.addRecord(sym: bind.place.sym, kind: .fwd)
      var exprType = genConstraints(scope, expr: bind.val)
      if let ann = bind.place.ann {
        exprType = addAnnConstraint(scope, expr: bind.val, ann: ann)
      }
      _ = scope.addRecord(sym: bind.place.sym, kind: .val(exprType))
      return typeVoid

    case .call(let call):
      _ = genConstraints(scope, expr: call.callee)
      _ = genConstraints(scope, expr: call.arg)
      let domType = addFreeType()
      let type = addFreeType()
      let sigType = Type.Sig(dom: domType, ret: type)
      constrain(call.callee, expType: sigType, "callee")
      constrain(call.arg, expType: domType, "argument")
      return type

    case .do_(let do_):
      return genConstraintsBody(scope, body: do_.body)

    case .fn(let fn):
      let type = Expr.sig(fn.sig).type(scope, "signature")
      guard case .sig(let dom, let ret) = type.kind else { fatalError() }
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord(name: "$", type: dom)
      fnScope.addValRecord(name: "self", type: type)
      _ = genConstraintsBody(fnScope, body: fn.body)
      constrain(fn.body.expr, expExpr: fn.sig.ret, expType: ret, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid: addFreeType() // all cases must return same type.
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, typeHalt support, etc.
      for case_ in if_.cases {
        let cond = case_.condition
        let cons = case_.consequence
        _ = genConstraints(scope, expr: cond)
        _ = genConstraints(scope, expr: cons)
        constrain(cond, expType: typeBool, "if form condition")
        constrain(cons, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        _ = genConstraints(scope, expr: dflt.expr)
        constrain(dflt.expr, expType: type, "if form default")
      }
      return type

    case .hostVal(let hostVal):
      for dep in hostVal.deps {
        _ = scope.getRecord(identifier: dep)
      }
      return hostVal.typeExpr.type(scope, "host value declaration")

    case .litNum:
      return typeInt

    case .litStr:
      return typeStr

    case .paren(let paren):
      if paren.isScalarValue {
        return genConstraints(scope, expr: paren.els[0])
      }
      let fields = paren.els.enumerated().map { self.typeFieldForArg(scope, arg: $1, index: $0) }
      return Type.Cmpd(fields)

    case .path(let path):
      let record = scope.getRecord(path: path)
      pathRecords[path] = record
      return path.syms.last!.typeForExprRecord(scope.getRecord(path: path))

    case .reify(let reify):
      reify.failType("type reification cannot be used as a value expression (temporary)")

    case .sig(let sig):
      sig.failType("type signature cannot be used as a value expression (temporary)")

    case .sym(let sym):
      let record = scope.getRecord(sym: sym)
      symRecords[sym] = record
      return sym.typeForExprRecord(record)

    case .void:
      return typeVoid
    }
  }


  mutating func addAnnConstraint(_ scope: Scope, expr: Expr, ann: Ann) -> Type {
    let type = ann.typeExpr.type(scope, "type annotation")
    constrain(expr, expExpr: ann.typeExpr, expType: type, "type annotation")
    return type
  }


  mutating func typeFieldForArg(_ scope: LocalScope, arg: Expr, index: Int) -> TypeField {
    let val: Expr
    switch arg {
      case .bind(let bind): val = bind.val
      default: val = arg
    }
    return TypeField(label: arg.argLabel, type: genConstraints(scope, expr: val))
  }


  mutating func genConstraintsBody(_ scope: LocalScope, body: Body) -> Type {
    for stmt in body.stmts {
      _ = genConstraints(scope, expr: stmt)
      self.constrain(stmt, expType: typeVoid, "statement")
    }
    return genConstraints(LocalScope(parent: scope), expr: body.expr)
  }
}
