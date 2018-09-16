// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


extension Expr {

  func simplify(_ ctx: DefCtx) -> Expr {
    // simplify `self` by converting high-level expressions like `where` into lower-level equivalents.

    switch self {

    case .acc(let acc): return .acc(Acc(acc.syn, accessor: acc.accessor, accessee: acc.accessee.simplify(ctx)))
    case .ann(let ann): return .ann(Ann(ann.syn, expr: ann.expr.simplify(ctx), typeExpr: ann.typeExpr))
    case .and(let and): return .and(And(and.syn, terms: and.terms.map{$0.simplify(ctx)}))
    case .bind(let bind): return .bind(Bind(bind.syn, place: bind.place, val: bind.val.simplify(ctx)))
    case .call(let call): return .call(Call(call.syn, callee: call.callee.simplify(ctx), arg: call.arg.simplify(ctx)))
    case .do_(let do_): return .do_(Do(do_.syn, body: simplifyBody(ctx, do_.body)))
    case .fn(let fn): return .fn(Fn(fn.syn, sig: fn.sig, body: simplifyBody(ctx, fn.body)))
    case .hostVal: return self

    case .if_(let if_): return .if_(If(if_.syn, cases: if_.cases.map{simplifyIfCase(ctx, $0)}, dflt: simplifyDefault(ctx, if_.dflt)))

    case .intersection: return self
    case .litNum: return self
    case .litStr: return self
    case .magic: return self

    case .match(let match): return genMatch(ctx,
      match: self,
      expr: match.expr.simplify(ctx),
      cases: match.cases.map{simplifyMatchCase(ctx, $0)},
      dflt: simplifyDefault(ctx, match.dflt))

    case .or(let or): return .or(Or(or.syn, terms: or.terms.map{$0.simplify(ctx)}))
    case .paren(let paren): return .paren(Paren(paren.syn, els: paren.els.map{$0.simplify(ctx)}))
    case .path: return self
    case .reif: return self
    case .sig: return self
    case .sym: return self
    case .tag: return self
    case .tagTest(let tagTest): return .tagTest(TagTest(tagTest.syn, tag: tagTest.tag, expr: tagTest.expr.simplify(ctx)))
    case .typeAlias: return self
    case .typeArgs: return self
    case .typeVar: return self
    case .union: return self
    case .void: return self
    case .where_: return self
    }
  }
}


func simplifyBody(_ ctx: DefCtx, _ body: Body) -> Body {
  return Body(body.syn, stmts: body.stmts.map{$0.simplify(ctx)}, expr: body.expr.simplify(ctx))
}


func simplifyDefault(_ ctx: DefCtx, _ dflt: Default?) -> Default? {
  guard let dflt = dflt else { return nil }
  return Default(dflt.syn, expr: dflt.expr.simplify(ctx))
}


func simplifyIfCase(_ ctx: DefCtx, _ case_: Case) -> Case {
  return Case(case_.syn, condition: case_.condition.simplify(ctx), consequence: case_.consequence.simplify(ctx))
}


func simplifyMatchCase(_ ctx: DefCtx, _ case_: Case) -> Case {
  return Case(case_.syn, condition: case_.condition, consequence: case_.consequence.simplify(ctx))
}
