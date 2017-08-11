// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension TypeCtx {

  mutating func track(expr: Expr, type: Type) {
    // Note: this functionality requires that a given Expr only be tracked once.
    // Therefore synthesized expressions cannot reuse input exprs multiple times.
    exprTypes.insertNew(expr, value: type)
  }


  mutating func addFreeType() -> Type {
    let t = Type.Free(freeTypeCount)
    freeTypeCount += 1
    return t
  }


  mutating func addConstraint(_ constraint: Constraint) {
    constraints.append(constraint)
    constraintsResolved.append(false)
  }


  mutating func constrain(_ actExpr: Expr, actType: Type, expExpr: Expr? = nil, expType: Type, _ desc: String) {
    addConstraint(.rel(RelCon(
      act: Side(expr: actExpr, type: actType),
      exp: Side(expr: expExpr ?? actExpr, type: expType),
      desc: desc)))
  }


  mutating func constrain(acc: Acc, accesseeType: Type) -> Type {
    let accType = addFreeType()
    addConstraint(.prop(PropCon(acc: acc, accesseeType: accesseeType, accType: accType)))
    return accType
  }


  mutating func genConstraints(_ scope: LocalScope, expr: Expr) -> Type {
    let type = genConstraintsDisp(scope, expr: expr)
    track(expr: expr, type: type)
    return type
  }


  mutating func genConstraintsDisp(_ scope: LocalScope, expr: Expr) -> Type {
    switch expr {

    case .acc(let acc):
      let accesseeType = genConstraints(scope, expr: acc.accessee)
      return constrain(acc: acc, accesseeType: accesseeType)

    case .and(let and):
      for term in and.terms {
        let termType = genConstraints(scope, expr: term)
        constrain(term, actType: termType, expType: typeBool, "`and` term")
      }
      return typeBool

    case .or(let or):
      for term in or.terms {
        let termType = genConstraints(scope, expr: term)
        constrain(term, actType: termType, expType: typeBool, "`or` term")
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
      let domType = addFreeType() // necessary to get the act/exp direction right.
      let retType = addFreeType()
      let sigType = Type.Sig(dom: domType, ret: retType)
      constrain(call.callee, actType: calleeType, expType: sigType, "callee")
      constrain(call.arg, actType: argType, expType: domType, "argument")
      return retType

    case .do_(let do_):
      return genConstraintsBody(LocalScope(parent: scope), body: do_.body)

    case .fn(let fn):
      let type = Expr.sig(fn.sig).type(scope, "signature")
      track(expr: .sig(fn.sig), type: type)
      guard case .sig(let dom, let ret) = type.kind else { fatalError() }
      let fnScope = LocalScope(parent: scope)
      fnScope.addValRecord(name: "$", type: dom)
      fnScope.addValRecord(name: "self", type: type)
      let bodyType = genConstraintsBody(fnScope, body: fn.body)
      constrain(fn.body.expr, actType: bodyType, expExpr: fn.sig.ret, expType: ret, "function body")
      return type

    case .if_(let if_):
      let type = (if_.dflt == nil) ? typeVoid: addFreeType() // all cases must return same type.
      // note: we could do without the freee type by generating constraints for dflt first,
      // but we prefer to generate constraints in lexical order for all cases.
      // TODO: much more to do here when default is missing;
      // e.g. inferring complete case coverage without default, typeHalt support, etc.
      for case_ in if_.cases {
        let cond = case_.condition
        let cons = case_.consequence
        let condType = genConstraints(scope, expr: cond)
        let consType = genConstraints(scope, expr: cons)
        constrain(cond, actType: condType, expType: typeBool, "if form condition")
        constrain(cons, actType: consType, expType: type, "if form consequence")
      }
      if let dflt = if_.dflt {
        let dfltType = genConstraints(scope, expr: dflt.expr)
        constrain(dflt.expr, actType: dfltType, expType: type, "if form default")
      }
      return type

    case .hostVal(let hostVal):
      for dep in hostVal.deps {
        _ = scope.getRecord(identifier: dep)
      }
      let type = hostVal.typeExpr.type(scope, "host value declaration")
      track(expr: hostVal.typeExpr, type: type)
      return type

    case .litNum:
      return typeInt

    case .litStr:
      return typeStr

    case .magic(let magic):
      return magic.type

    case .match(let match):
      let valSym = genSym(parent: match.expr)
      let do_ = putSynth(source: expr, expr: genMatch(match: match, valSym: valSym))
      let type = genConstraints(scope, expr: do_)
      return type

    case .paren(let paren):
      if paren.isScalarValue {
        return genConstraints(scope, expr: paren.els[0])
      }
      var fields = [TypeField]()
      var variants = [TypeField]()
      for el in paren.els {
        let member = self.typeFieldForArg(scope, arg: el)
        if member.isVariant {
          if !variants.isEmpty {
            el.failSyntax("struct literal cannot contain multiple tagged elements")
          }
          variants.append(member)
        } else {
          if !variants.isEmpty {
            el.failSyntax("struct literal field cannot follow a variant")
          }
          fields.append(member)
        }
      }
      return Type.Struct(fields: fields, variants: variants)

    case .path(let path):
      return constrainSym(sym: path.syms.last!, record: scope.getRecord(path: path))

    case .reify(let reify):
      reify.failType("type reification cannot be used as a value expression (temporary)")

    case .sig(let sig):
      sig.failType("type signature cannot be used as a value expression.")

    case .sym(let sym):
      return constrainSym(sym: sym, record: scope.getRecord(sym: sym))

    case .tag(let tag): // bare morph constructor.
      return Type.Variant(label: tag.sym.name, type: typeVoid)

    case .tagTest(let tagTest):
      let expr = tagTest.expr
      let actType = genConstraints(scope, expr: expr)
      let expType = Type.VariantMember(variant: TypeField(isVariant: true, label: tagTest.tag.sym.name, type: addFreeType()))
      constrain(expr, actType: actType, expExpr: .tag(tagTest.tag), expType: expType, "tag test")
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

    case .void:
      return typeVoid

    case .where_(let where_):
      where_.failSyntax("where phrase cannot be used as a value expression.")
    }
  }


  mutating func constrainAnn(_ scope: Scope, expr: Expr, type: Type, ann: Ann) -> Type {
    let annType = ann.typeExpr.type(scope, "type annotation")
    track(expr: ann.typeExpr, type: annType)
    constrain(expr, actType: type, expExpr: ann.typeExpr, expType: annType, "annotated:")
    return annType
  }


  mutating func typeFieldForArg(_ scope: LocalScope, arg: Expr) -> TypeField {
    var isVariant = false
    let type: Type
    switch arg {
    case .bind(let bind):
      isVariant = bind.place.isTag
      type = genConstraints(scope, expr: bind.val)
    case .tag:
      isVariant = true
      type = typeVoid
    default:
      type = genConstraints(scope, expr: arg)
    }
    return TypeField(isVariant: isVariant, label: arg.argLabel, type: type)
  }


  mutating func genConstraintsBody(_ scope: LocalScope, body: Body) -> Type {
    for stmt in body.stmts {
      let type = genConstraints(scope, expr: stmt)
      constrain(stmt, actType: type, expType: typeVoid, "statement")
    }
    return genConstraints(scope, expr: body.expr)
  }


  mutating func constrainSym(sym: Sym, record: ScopeRecord) -> Type {
    symRecords[sym] = record
    switch record.kind {
    case .lazy(let type): return type
    case .poly(let polytype, _):
      let morphType = addFreeType()
      constrain(.sym(sym), actType: polytype, expType: morphType, "polymorph alias '\(sym.name)':")
      return morphType
    case .val(let type): return type
    default: sym.failScope("expected a value; `\(sym.name)` refers to a \(record.kindDesc).")
    }
  }


  mutating func putSynth(source: Expr, expr: Expr) -> Expr {
    synths.insertNew(source, value: expr)
    return expr
  }


  mutating func getSynth(source: Expr) -> Expr {
    return synths[source]!
  }


  mutating func genSym(parent: Expr) -> Sym {
    let sym = Sym(parent.syn, name: "$g\(genSyms.count)") // bling: $g<i>: gensym.
    genSyms.append(sym)
    return sym
  }
}
