// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Path: _Form, Expr, Identifier, TypeExpr { // path: `LIB/name`.
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
  
  func compileExpr(em: Emit, _ depth: Int, _ scope: Scope, _ expType: Type, isTail: Bool) -> Type {
    return syms.last!.compileSym(em, depth, scope.rec(self), expType, isTail: isTail)
  }

  func typeVal(scope: Scope, _ subj: String) -> Type {
    return syms.last!.typeValForTypeRecord(scope.rec(self), subj)
  }
}

