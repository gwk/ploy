// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


var globalDbgDefSuffixes: Set<String> = []


class DefCtx: Encodable {

  enum CodingKeys: CodingKey {
    case path
    case typeCtx
  }

  let globalCtx: GlobalCtx
  let path: String
  let dbg: Bool
  var typeCtx = TypeCtx()

  var exprTypes = [Expr:Type]() // maps expressions to their types.
  var symRecords = [Sym:ScopeRecord]()

  private var genSymCount = 0

  init(globalCtx: GlobalCtx, path: String) {
    self.globalCtx = globalCtx
    self.path = path
    self.dbg = globalDbgDefSuffixes.any { path.hasSuffix($0) }
    if self.dbg {
      errSL("PLOY_DBG_DEFS: will dump info for `\(path)`.")
      typeCtx.dumpMethodResolutionErrors = true
    }
  }


  func typecheck() {
    do {
      try typeCtx.resolveAll()
    } catch let err as PropCon.Err {
      dumpDbg()
      typeCtx.error(err)
    } catch let err as RelCon.Err {
      dumpDbg()
      typeCtx.error(err)
    } catch let err { fatalError(String(describing: err)) }
    // fill in frees that were only bound to Never.
    typeCtx.fillFreeNevers()
    // check that resolution is complete.
    for expr in exprTypes.keys {
      let type = typeFor(expr: expr)
      if type.frees.count > 0 {
        dumpDbg()
        fatalError("unresolved frees in type: \(type)")
      }
    }
    dumpDbg()
  }


  func dumpDbg() {
    if self.dbg {
      globalCtx.dump(object: self)
    }
  }


  func genSym(parent: Expr) -> Sym {
    let sym = Sym(parent.syn, name: "$g\(genSymCount)") // bling: $g<i>: gensym.
    genSymCount += 1
    return sym
  }


  func typeFor(expr: Expr) -> Type {
    guard let type = exprTypes[expr] else { expr.fatal("untracked expression") }
    return typeCtx.resolved(type: type)
  }


  func track(expr: Expr, type: Type) {
    // Map an expression to a type, so that the output phase can look up the final resolved type.
    // Note: this functionality requires that a given Expr only be tracked once.
    // Therefore synthesized expressions cannot reuse input exprs multiple times.
    exprTypes.insertNew(expr, value: type)
  }


  func constrain(
   actRole: Side.Role = .act, actExpr: Expr, actType: Type,
   expRole: Side.Role = .exp, expExpr: Expr? = nil, expType: Type, _ desc: String) {
    typeCtx.addConstraint(.rel(RelCon(
      act: Side(actRole, expr: actExpr, type: actType),
      exp: Side(expRole, expr: expExpr ?? actExpr, type: expType),
      desc: desc)))
  }


  func constrain(acc: Acc, accesseeType: Type) -> Type {
    let accType = typeCtx.addFreeType()
    typeCtx.addConstraint(.prop(PropCon(acc: acc, accesseeType: accesseeType, accType: accType)))
    return accType
  }


  func genConstraints(_ scope: LocalScope, expr: Expr, ann: Ann?) -> Type {
    // Entry point into constraint generation.
    var type = genConstraints(scope, expr: expr)
    if let ann = ann {
      type = constrainAnn(scope, expr: expr, type: type, ann: ann)
    }
    return type
  }


  func genConstraints(_ scope: LocalScope, expr: Expr) -> Type {
    let type = genConstraintsDisp(scope, expr: expr)
    track(expr: expr, type: type)
    return type
  }


  func genConstraintsDisp(_ scope: LocalScope, expr: Expr) -> Type {
    switch expr {

    case .acc(let acc):
      let accesseeType = genConstraints(scope, expr: acc.accessee)
      return constrain(acc: acc, accesseeType: accesseeType)

    case .and(let and):
      for term in and.terms {
        let termType = genConstraints(scope, expr: term)
        constrain(actExpr: term, actType: termType, expType: typeBool, "`and` term")
      }
      return typeBool

    case .or(let or):
      for term in or.terms {
        let termType = genConstraints(scope, expr: term)
        constrain(actExpr: term, actType: termType, expType: typeBool, "`or` term")
      }
      return typeBool

    case .ann(let ann):
      let type = genConstraints(scope, expr: ann.expr)
      return constrainAnn(scope, expr: ann.expr, type: type, ann: ann)

    case .bind(let bind):
      _ = scope.addRecord(sym: bind.place.sym, kind: .fwd)
      var exprType = genConstraints(scope, expr: bind.val)
      if let ann = bind.place.ann {
        exprType = constrainAnn(scope, expr: bind.val, type: exprType, ann: ann)
      }
      _ = scope.addRecord(sym: bind.place.sym, kind: .val(exprType))
      return typeVoid

    case .call(let call):
      let calleeType = genConstraints(scope, expr: call.callee)
      let argType = genConstraints(scope, expr: call.arg)
      let domType = typeCtx.addFreeType()
      let retType = typeCtx.addFreeType()
      let sigType = Type.Sig(dom: domType, ret: retType)
      constrain(actExpr: call.callee, actType: calleeType, expType: sigType, "callee")
      constrain(actRole: .arg, actExpr: call.arg, actType: argType, expRole: .dom, expExpr: call.callee, expType: domType, "call")
      return retType

    case .do_(let do_):
      return genConstraintsForBody(LocalScope(parent: scope), body: do_.body)

    case .fn(let fn):
      let type = Expr.sig(fn.sig).type(scope, "signature")
      track(expr: .sig(fn.sig), type: type) // track the sig so that compile can look up the expectation for body.
      let (dom, ret) = type.sigDomRet
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord(name: "$", type: dom)
      fnScope.addValRecord(name: "self", type: type)
      let bodyType = genConstraintsForBody(fnScope, body: fn.body)
      constrain(actExpr: fn.body.expr, actType: bodyType, expRole: .ret, expExpr: fn.sig.ret, expType: ret, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid : typeCtx.addFreeType() // all cases must return same type.
      // note: we could do without the free type by generating constraints for dflt first,
      // but we prefer to generate constraints in lexical order for all cases.
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, Never support, etc.
      for case_ in if_.cases {
        let cond = case_.condition
        let cons = case_.consequence
        let condType = genConstraints(scope, expr: cond)
        let consType = genConstraints(scope, expr: cons)
        constrain(actExpr: cond, actType: condType, expType: typeBool, "if form condition")
        constrain(actExpr: cons, actType: consType, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        let dfltType = genConstraints(scope, expr: dflt.expr)
        constrain(actExpr: dflt.expr, actType: dfltType, expType: type, "if form default")
      }
      return type

    case .intersection: fatalError()

    case .hostVal(let hostVal):
      for dep in hostVal.deps {
        _ = scope.getRecord(identifier: dep)
      }
      let type = hostVal.typeExpr.type(scope, "host value declaration")
      return type

    case .litNum:
      return typeInt

    case .litStr:
      return typeStr

    case .magic(let magic):
      return magic.type

    case .match: fatalError() // removed by simplify().

    case .paren(let paren):
      if paren.isScalarValue {
        return genConstraints(scope, expr: paren.els[0])
      }
      return mkStructType(isLiteral: true, exprs: paren.els) {
        self.typeMemberForLiteral(scope, arg: $0)
      }

    case .path(let path):
      return localTypeFor(scope: scope, identifier: .path(path))

    case .reif(let reif):
      let record = scope.getRecord(identifier: reif.abstract)
      symRecords[reif.abstract.lastSym] = record
      let abstractType: Type
      switch record.kind {
        case .poly(let polyRec):
          abstractType = typeCtx.addFreeType() // Method type. Any necessary instantiation happens during method resolution.
          constrain(actRole: .poly, actExpr: reif.abstract.expr, actType: polyRec.polytype,
            expType: abstractType, "method alias '\(reif.abstract.name)':")
        default: reif.abstract.failScope("expected an instantiable reference; found a \(record.kindDesc)")
      }
      reif.failType("type reification not yet implemented")
      // Since generics are now exclusively implemented as polyfunctions,
      // function reification expressions no longer make sense.
      // They might still be useful to the programmer for denoting intention,
      // but it is not clear if that should be implemented using abstractExpr.reify() or alternatively by adding constraints.
      // The reify() mechanism will probably still be used for generic types however.
      //let abstractExpr = reif.abstract.expr
      //let reifiedType = abstractExpr.reify(scope, type: abstractType, typeArgs: reif.args)
      //let monotype = instantiate(expr: expr, type: reifiedType)
      //track(expr: abstractExpr, type: monotype) // so that Expr.compile can just dispatch to reif.abstract.
      //return monotype

    case .sig(let sig):
      sig.failType("type signature cannot be used as a value expression.")

    case .sym(let sym):
      return localTypeFor(scope: scope, identifier: .sym(sym))

    case .tag(let tag): // bare morph constructor.
      return Type.Variant(label: tag.sym.name, type: typeNull)

    case .tagTest(let tagTest):
      let expr = tagTest.expr
      let actType = genConstraints(scope, expr: expr)
      let expVariant = TypeVariant(label: tagTest.tag.sym.name, type: typeCtx.addFreeType())
      let expType = Type.VariantMember(variant: expVariant)
      constrain(actExpr: expr, actType: actType, expExpr: .tag(tagTest.tag), expType: expType, "tag test")
      return typeBool

    case .typeAlias(let typeAlias):
      _ = scope.addRecord(sym: typeAlias.sym, kind: .fwd)
      let type = typeAlias.expr.type(scope, "type alias")
      _ = scope.addRecord(sym: typeAlias.sym, kind: .type(type))
      return typeVoid

    case .typeArgs(let typeArgs): // TODO: impossible? fatalError?
      typeArgs.failType("type args cannot be used as a value expression.")

    case .typeVar(let typeVar):
      typeVar.failType("type variable declaration cannot be used as a value expression.")

    case .union: fatalError()

    case .void:
      return typeVoid

    case .where_(let where_):
      where_.failSyntax("\"where\" clause type refinement cannot be used as a value expression.")
    }
  }


  func constrainAnn(_ scope: LocalScope, expr: Expr, type: Type, ann: Ann) -> Type {
    let annType = ann.typeExpr.type(scope, "type annotation")
    track(expr: ann.typeExpr, type: annType)
    constrain(actExpr: expr, actType: type, expExpr: ann.typeExpr, expType: annType, "annotated:")
    return annType
  }


  func typeMemberForLiteral(_ scope: LocalScope, arg: Expr) -> TypeMember {
    switch arg {
    case .bind(let bind):
      let label = arg.argLabel!
      let type = genConstraints(scope, expr: bind.val)
      if bind.place.isTag {
        return .variant(TypeVariant(label: label, type: type))
      } else {
        return .labField(TypeLabField(label: label, type: type))
      }
    case .tag:
      return .variant(TypeVariant(label: arg.argLabel!, type: typeNull))
    default:
      return .posField(genConstraints(scope, expr: arg))
    }
  }


  func genConstraintsForBody(_ scope: LocalScope, body: Body) -> Type {
    for stmt in body.stmts {
      let type = genConstraints(scope, expr: stmt)
      constrain(actExpr: stmt, actType: type, expType: typeVoid, "statement")
    }
    return genConstraints(scope, expr: body.expr)
  }


  func localTypeFor(scope: LocalScope, identifier: Identifier) -> Type {
    let record = scope.getRecord(identifier: identifier)
    symRecords[identifier.lastSym] = record
    switch record.kind {
    case .lazy(let type): return record.isLocal ? type : instantiate(expr: identifier.expr, type: type)
    case .val(let type):  return record.isLocal ? type : instantiate(expr: identifier.expr, type: type)
    case .poly(let polyRec):
      assert(!record.isLocal)
      let type = typeCtx.addFreeType() // Method type. Any necessary instantiation happens during method resolution.
      constrain(actRole: .poly, actExpr: identifier.expr, actType: polyRec.polytype,
        expType: type, "method alias '\(identifier.name)':")
      return type
    default: identifier.expr.failScope("expected a value; `\(identifier.name)` refers to a \(record.kindDesc).")
    }
  }


  func instantiate(expr: Expr, type: Type) -> Type {
    return typeCtx.instantiate(expr: expr, type: type)
  }
}
