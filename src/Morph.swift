// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.

class Morph {
  var defCtx: DefCtx?
  let val: Expr

  init(defCtx: DefCtx?, val: Expr) {
    self.defCtx = defCtx
    self.val = val
  }
}
