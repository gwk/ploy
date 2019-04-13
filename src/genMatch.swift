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
      default: bind.place.failSyntax("destructuring bind place must be a symbol or tag")
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

    case .paren(let paren): // Match syntax follows that of literal value constructors, as opposed to type declarations.
      if paren.isScalarValue {
        destructure(val: val, pattern: paren.els[0])
        return
      }
      // Note the difference in access for fields versus the sole variant:
      // For fields, decompose `val` with `subAcc`.
      // For the optional variant, recurse into `destructure`, passing the whole `val`,
      // which then gets destructured by the `.bind` or `.tag` case.
      var prevVariant: Expr? = nil
      for (i, el) in paren.els.enumerated() {
        if el.isTagged { // Variant.
          if let prevVariant = prevVariant {
            el.failSyntax("destructuring does not support more than one variant.",
              notes: (prevVariant, "first variant is here."))
          }
          prevVariant = el
          destructure(val: val, pattern: el)
        } else { // Field.
          switch el {
          case .bind:
            destructure(val: val.cloned, pattern: el) // Pass the whole val, which then gets destructured appropriately.
          default:
            destructure(val:subAcc(accessor: .litNum(LitNum(el.syn, val: i)), val: val), pattern: el)
          }
        }
      }

    case .sym(let sym):
      binds.append(Bind(sym.syn, place: .sym(sym), val: val.cloned))

    case .tag(let tag):
      tests.append(synthTagTest(tag: tag, val: val))

    case .typeRefine(let typeRefine): typeRefine.fatal("match type refinement clauses not implemented.")

    default: pattern.failSyntax("match case expected pattern; received \(cond.actDesc).")
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

