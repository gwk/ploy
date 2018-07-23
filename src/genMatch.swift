// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


func genMatch(_ ctx: DefCtx, match: Expr, expr: Expr, cases: [Case], dflt: Default?) -> Expr {
  // Reduce the match form down to simpler syntax.
  // This is a purely syntactic process; the result is type checked.
  let valSym = ctx.genSym(parent: match)
  let exprBind = Expr.bind(Bind(expr.syn, place: .sym(valSym), val: expr))
  let if_ = If(match.syn,
    cases: cases.map { genMatchCase(matchValSym: valSym, case_: $0) },
    dflt: dflt ?? Default(match.syn, expr: .call(Call(match.syn,
      callee: .sym(Sym(match.syn, name: "fail")),
      arg: .litStr(LitStr(match.syn, val: "match failed: \(match.syn)."))))))
  return .do_(Do(match.syn, stmts: [exprBind], expr: .if_(if_)))
}


func genMatchCase(matchValSym: Sym, case_: Case) -> Case {
  // Synthesize an `if` case from a `match` case.
  // matchValSym is the generated sym bound to the match value expression.
  // All syntax nodes must not appear more than once in the output tree; see TypeCtx.track().
  // Instead we clone nodes that get used more than once.
  // Note: the synthesized calls to ROOT/eq result in somewhat cryptic type errors regarding type of 'eq'.
  // Not sure how that should be addressed;
  // perhaps the constraint could be given the function name wherever it is known.
  let cond = case_.condition
  let cons = case_.consequence
  var tests = [Expr]()
  var binds = [Bind]()

  func destructure(val: Expr, pattern: Expr) {

    switch pattern {

    case .bind(let bind):
      switch bind.place {
      case .sym(let sym): // field.
        destructure(val: subAcc(accessor: .sym(sym), val: val), pattern: bind.val)
      case .tag(let tag): // variant.
        tests.append(synthTagTest(tag: tag, val: val))
        destructure(val: subAcc(accessor: .untag(tag), val: val), pattern: bind.val)
      default: bind.place.form.failSyntax("destructuring bind place must be a sym or tag")
      }

    case .litNum(let litNum):
      let syn = litNum.syn
      tests.append(synthCall(syn,
        callee: synthPath(syn, "ROOT", "eq"),
        args: val.cloned, .litNum(litNum))) // sole use of litNum.

    case .litStr(let litStr):
      let syn = litStr.syn
      tests.append(synthCall(syn,
        callee: synthPath(syn, "ROOT", "eq"),
        args: val.cloned, .litStr(litStr))) // sole use of litStr.

    case .paren(let paren):
      if paren.isScalarValue { // match syntax follows that of value constructors, as opposed to type declarations.
        destructure(val: val, pattern: paren.els[0])
        return
      }
      // note the difference in access for fields versus the sole variant:
      // we iterate over fields and decompose `val` with `SubAcc`;
      // for the optional variant we recurse into `destructure`, passing the whole `val`.
      for (i, el) in paren.fieldEls.enumerated() {
        var elVal: Expr
        switch el {
        case .bind: elVal = val.cloned // pass the whole val; bind case above handles subAcc.
        default: elVal = subAcc(accessor: .litNum(LitNum(el.syn, val: i)), val: val)
        }
        destructure(val: elVal, pattern: el)
      }
      let variantEls = paren.variantEls
      if let variant = variantEls.first {
        if variantEls.count > 1 {
          variantEls[1].failSyntax("destructuring does not support more than one variant.",
            notes: (variant.form, "first variant is here."))
        }
        destructure(val: val, pattern: variant)
      }

    case .sym(let sym):
      binds.append(Bind(sym.syn, place: .sym(sym), val: val.cloned))

    case .tag(let tag):
      tests.append(synthTagTest(tag: tag, val: val))

    case .where_(let where_): where_.fatal("match where clauses not implemented.")

    default: pattern.failSyntax("match case expected pattern; received \(cond.form.syntaxName).")
    }
  }

  destructure(val: .sym(matchValSym), pattern: cond)
  let genCond = Expr.and(And(cond.syn, terms: tests))
  let genCons = binds.isEmpty
  ? cons
  : .do_(Do(cons.syn, body: Body(cons.syn, stmts: binds.map {.bind($0)}, expr: cons)))
  return Case(case_.syn, condition: genCond, consequence: genCons)
}


func subAcc(accessor: Accessor, val: Expr) -> Expr {
  return .acc(Acc(accessor.syn, accessor: accessor.cloned, accessee: val.cloned))
}

func synthPath(_ syn: Syn, _ names: String...) -> Expr {
  return .path(SymPath(syn, syms: names.map { Sym(syn, name: $0) }))
}


func synthCall(_ syn: Syn, callee: Expr, args: Expr...) -> Expr {
  return .call(Call(syn, callee: callee, arg: .paren(Paren(syn, els: args))))
}

func synthTagTest(tag: Tag, val: Expr) -> Expr {
  return .tagTest(TagTest(tag.syn, tag: tag.cloned, expr: val.cloned))
}

