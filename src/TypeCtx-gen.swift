// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


extension TypeCtx {

  mutating func track(expr: Expr, type: Type) {
    // Note: this functionality requires that a given piece Expr only be tracked once.
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
      let valSyn = match.expr.syn
      let valSym = genSym(parent: match.expr)
      let exprBind = Expr.bind(Bind(valSyn, place: .sym(valSym), val: match.expr))
      let if_ = If(match.syn,
        cases: match.cases.map {
          genMatchCase(valSyn: valSyn, valName: valSym.name, caseSyn: $0.syn, condition: $0.condition, consequence: $0.consequence)
        },
        dflt: match.dflt ?? Default(match.syn, expr: .call(Call(match.syn,
          callee: .sym(Sym(match.syn, name: "fail")),
          arg: .litStr(LitStr(match.syn, val: "match failed: \(match.syn)."))))))

      let do_ = putSynth(src: expr, expr: .do_(Do(match.syn, stmts: [exprBind], expr: .if_(if_))))
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
            el.form.failSyntax("struct literal cannot contain multiple tagged elements")
          }
          variants.append(member)
        } else {
          if !variants.isEmpty {
            el.form.failSyntax("struct literal field cannot follow a variant")
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
      sig.failType("type signature cannot be used as a value expression (temporary)")

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

    case .void:
      return typeVoid

    case .where_(let where_):
      where_.failSyntax("where phrase cannot be used as a value expression (temporary)")
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


  mutating func putSynth(src: Expr, expr: Expr) -> Expr {
    synths.insertNew(src, value: expr)
    return expr
  }


  mutating func getSynth(src: Expr) -> Expr {
    return synths[src]!
  }


  mutating func genSym(parent: Expr) -> Sym {
    let sym = Sym(parent.syn, name: "$g\(genSyms.count)") // bling: $g<i>: gensym.
    genSyms.append(sym)
    return sym
  }
}


func synthSym(_ syn: Syn, _ name: String) -> Expr {
  return .sym(Sym(syn, name: name))
}

func synthPath(_ syn: Syn, _ names: String...) -> Expr {
  return .path(Path(syn, syms: names.map { Sym(syn, name: $0) }))
}

func synthCall(_ syn: Syn, callee: Expr, args: Expr...) -> Expr {
  return .call(Call(syn, callee: callee, arg: .paren(Paren(syn, els: args))))
}

func genMatchCase(valSyn: Syn, valName: String, caseSyn: Syn, condition: Expr, consequence: Expr) -> Case {
  // Synthesize an `if` case from a `match` case.
  // This is a purely syntactic process; the result is type checked.
  // valSyn/valName belong to the synthesized symbol bound to the match argument value.
  // The actual symbol is not passed here because it must not be incorporated into synthesized cases; see track().
  // Instead use valSym() to synthesize a new reference.
  // We can reuse original bits of syntax from the condition, but only if they only appear once in the output.
  // Note: the synthesized calls to ROOT/eq result in somewhat cryptic type errors regarding type signature of 'eq'.
  // Not sure how that should be addressed; seems like the constraint should be given the function name wherever it is known.
  var tests = [Expr]()
  var binds = [Bind]()

  func valSym() -> Expr { return synthSym(valSyn, valName) }

  func synthTagTest(tag: Tag) -> Expr {
    return .tagTest(TagTest(tag.syn, tag: tag, expr: valSym())) // assumes sole use of tag.
  }

  func dispatch(expr: Expr) {
    switch expr {

    case .litNum(let litNum):
      let syn = litNum.syn
      tests.append(synthCall(syn,
        callee: synthPath(syn, "ROOT", "eq"),
        args: valSym(), .litNum(litNum))) // sole use of litNum.

    case .litStr(let litStr):
      let syn = litStr.syn
      tests.append(synthCall(syn,
        callee: synthPath(syn, "ROOT", "eq"),
        args: valSym(), .litStr(litStr))) // sole use of litStr.

    case .tag(let tag):
      tests.append(synthTagTest(tag: tag)) // sole use of tag.

    case .paren(let paren):
      if paren.els.count != 1 { paren.failSyntax("TODO: destructuring structs not yet supported") }
      switch paren.els[0] {

      case .bind(let bind):
        var unwrapped: Expr! = nil
        switch bind.place {
        case .ann(let ann): ann.failSyntax("destructuring bind symbol cannot be annotated")
        case .sym(let sym): sym.failSyntax("destructuring bind: TODO: struct fields")
        case .tag(let tag):
          tests.append(synthTagTest(tag: tag))
          unwrapped = .acc(Acc(tag.syn, accessor: .untag(tag.sym), accessee: valSym())) // sole use of tag.sym.
        }
        switch bind.val {
        case .sym(let sym):
          binds.append(Bind(sym.syn, place: .sym(sym), val: unwrapped)) // sole use of sym.
        default: bind.val.form.failSyntax("destructuring bind right side must be a destructuring (sym or struct)")
        }

      default: paren.failSyntax("destructuring paren: TODO: incomplete")
      }

    case .sym(let sym):
      binds.append(Bind(sym.syn, place: .sym(sym), val: valSym())) // sole use of sym.

    case .where_(let where_): fatalError("TODO: \(where_)")

    default: expr.form.failSyntax("match case expects pattern; received \(condition.form.syntaxName)")
    }
  }

  dispatch(expr: condition)
  let genCond = Expr.and(And(condition.syn, terms: tests))
  let genCons = binds.isEmpty
  ? consequence
  : .do_(Do(consequence.syn, body: Body(consequence.syn, stmts: binds.map {.bind($0)}, expr: consequence)))
  return Case(caseSyn, condition: genCond, consequence: genCons)
}
