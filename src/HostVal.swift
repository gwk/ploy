// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class HostVal: ActFormBase, ActForm { // host value declaration: `host_val sym Type deps*;`.
  let typeExpr: Expr
  let deps: [Identifier]
  let code: LitStr

  init(_ syn: Syn, typeExpr: Expr, code: LitStr, deps: [Identifier]) {
    self.typeExpr = typeExpr
    self.deps = deps
    self.code = code
    super.init(syn)
  }

  static var expDesc: String { return "`host_val`" }

  var textTreeChildren: [Any] { return [typeExpr, code] + deps }
}
