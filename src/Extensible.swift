// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Extensible: Form {
  let sym: Sym
  let constraints: [Expr]

  init(_ syn: Syn, sym: Sym, constraints: [Expr]) {
    self.sym = sym
    self.constraints = constraints
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return [sym] + constraints }
}
