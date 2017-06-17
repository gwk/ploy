// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


func genMatch(match: Match, valSym: Sym) -> Expr {
  // Reduce the match form down to simpler syntax.
  // This is a purely syntactic process; the result is type checked.
  let exprBind = Expr.bind(Bind(match.expr.syn, place: .sym(valSym), val: match.expr))
  let if_ = If(match.syn,
    cases: match.cases.map { genMatchCase(matchValSym: valSym, case_: $0) },
    dflt: match.dflt ?? Default(match.syn, expr: .call(Call(match.syn,
      callee: .sym(Sym(match.syn, name: "fail")),
      arg: .litStr(LitStr(match.syn, val: "match failed: \(match.syn)."))))))
  return .do_(Do(match.syn, stmts: [exprBind], expr: .if_(if_)))
}


func genMatchCase(matchValSym: Sym, case_: Case) -> Case {
  // Synthesize an `if` case from a `match` case.
  // valSym is the generated sym bound to the match value expression.
  // It must not be incorporated into synthesized cases; see TypeCtx.track().
  // Instead use synth(sym: valSym) to clone the symbol.
  // We can reuse original bits of syntax from the condition, but only if they only appear once in the output.
  // Note: the synthesized calls to ROOT/eq result in somewhat cryptic type errors regarding type signature of 'eq'.
  // Not sure how that should be addressed; seems like the constraint should be given the function name wherever it is known.
  let cond = case_.condition
  let cons = case_.consequence
  var tests = [Expr]()
  var binds = [Bind]()

  func destructure(val valSymOrig: Sym, pattern: Expr) {

    func valSym() -> Expr { return .sym(valSymOrig.cloned) }

    func synthTagTest(tag: Tag) -> Expr {
      return .tagTest(TagTest(tag.syn, tag: tag.cloned, expr: valSym()))
    }

    switch pattern {

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

    case .paren(let paren):
      if paren.isScalarValue { // match syntax follows that of value constructors, as opposed to type declarations.
        destructure(val: valSymOrig, pattern: paren.els[0])
        return
      }
      for el in paren.fieldEls {
        el.failSyntax("destructuring does not yet support fields")
      }
      let variantEls = paren.variantEls
      if variantEls.isEmpty { return }
      let variant = variantEls[0]
      if variantEls.count > 1 {
        variantEls[1].failSyntax("destructuring does not support more than one variant",
          notes: (variant.form, "first variant is here"))
      }
      switch variant {
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
        default: bind.val.failSyntax("destructuring bind right side must be a destructuring (sym or struct)")
        }

      default: paren.failSyntax("destructuring paren: TODO: incomplete")
      }

    case .sym(let sym):
      binds.append(Bind(sym.syn, place: .sym(sym), val: valSym())) // sole use of sym.

    case .tag(let tag):
      tests.append(synthTagTest(tag: tag)) // sole use of tag.

    case .where_(let where_): fatalError("TODO: \(where_)")

    default: pattern.failSyntax("match case expects pattern; received \(cond.form.syntaxName)")
    }
  }

  destructure(val: matchValSym, pattern: cond)
  let genCond = Expr.and(And(cond.syn, terms: tests))
  let genCons = binds.isEmpty
  ? cons
  : .do_(Do(cons.syn, body: Body(cons.syn, stmts: binds.map {.bind($0)}, expr: cons)))
  return Case(case_.syn, condition: genCond, consequence: genCons)
}


func synthPath(_ syn: Syn, _ names: String...) -> Expr {
  return .path(Path(syn, syms: names.map { Sym(syn, name: $0) }))
}


func synthCall(_ syn: Syn, callee: Expr, args: Expr...) -> Expr {
  return .call(Call(syn, callee: callee, arg: .paren(Paren(syn, els: args))))
}
