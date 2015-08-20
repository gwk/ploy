// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Path: _Form, Expr, TypeExpr { // symbol: `name`.
  let syms: [Sym]
  
  init(_ syn: Syn, syms: [Sym]) {
    check(syms.count > 0)
    self.syms = syms
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    var first = true
    for s in syms {
      if first {
        first = false
      } else {
        target.write("/")
      }
      target.write(s.name)
    }
    target.write("\n")
  }
  
  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    return syms.last!.typeVal(scope.rec(self), subj)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    return syms.last!.compile(em, depth, scope.rec(self), expType)
  }
}

