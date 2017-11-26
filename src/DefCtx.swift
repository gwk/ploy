// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class DefCtx {

  let globalCtx: GlobalCtx

  var genSyms = [Sym]()

  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }

  func genSym(parent: Expr) -> Sym {
    let sym = Sym(parent.syn, name: "$g\(genSyms.count)") // bling: $g<i>: gensym.
    genSyms.append(sym)
    return sym
  }
}
