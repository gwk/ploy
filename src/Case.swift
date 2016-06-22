// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Case: _Form { // conditional case: `condition ? consequence`.
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
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    condition.write(to: &stream, depth + 1)
    consequence.write(to: &stream, depth + 1)
  }
}

