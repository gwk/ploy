// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.

class Morph {
  var defCtx: DefCtx?
  let val: Expr
  let type: Type
  var needsLazy: Bool? = nil

  init(defCtx: DefCtx, val: Expr, type: Type) {
    self.defCtx = defCtx
    self.val = val
    self.type = type
  }
}
