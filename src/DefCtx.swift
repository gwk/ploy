// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class DefCtx {

  let globalCtx: GlobalCtx
  var typeCtx = TypeCtx()

  var exprTypes = [Expr:Type]() // maps expressions to their types.
  var symRecords = [Sym:ScopeRecord]()

  private var genSymCount = 0

  init(globalCtx: GlobalCtx) {
    self.globalCtx = globalCtx
  }


  func typecheck() {
    typeCtx.resolveOrError()
    // check that resolution is complete.
    for expr in exprTypes.keys {
      let type = typeFor(expr: expr)
      if type.frees.count > 0 {
        fatalError("unresolved frees in type: \(type)")
      }
    }
  }


  func genSym(parent: Expr) -> Sym {
    let sym = Sym(parent.syn, name: "$g\(genSymCount)") // bling: $g<i>: gensym.
    genSymCount += 1
    return sym
  }


  func typeFor(expr: Expr) -> Type {
    guard let type = exprTypes[expr] else { expr.form.fatal("untracked expression") }
    return typeCtx.resolved(type: type)
  }
}
