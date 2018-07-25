// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: Form { // host value declaration: `host_val sym Type deps*;`.
  let typeExpr: Expr
  let code: LitStr
  let deps: [Identifier]

  init(_ syn: Syn, typeExpr: Expr, code: LitStr, deps: [Identifier]) {
    self.typeExpr = typeExpr
    self.code = code
    self.deps = deps
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return [typeExpr, code] + deps }
}
