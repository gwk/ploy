// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Case: _Form, Form { // conditional case: `condition ? consequence`.
  let condition: Expr
  let consequence: Expr

  init (_ syn: Syn, condition: Expr, consequence: Expr) {
    self.condition = condition
    self.consequence = consequence
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Case(Syn(l.syn, r.syn),
      condition: castForm(l, "case", "condition"),
      consequence: castForm(r, "case", "consequence"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    condition.writeTo(&target, depth + 1)
    consequence.writeTo(&target, depth + 1)
  }
}

