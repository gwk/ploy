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
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
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

  // MARK: Expr

  func compileExpr(ctx: TypeCtx, _ depth: Int, _ scope: LocalScope, _ expType: Type, isTail: Bool) -> Type {
    return syms.last!.compileSym(ctx, depth, scope.em, scope.record(self), expType, isTail: isTail)
  }

  // MARK: Identifier

  var name: String { return syms.map({$0.name}).joinWithSeparator("/") }
  
  func record(scope: Scope, _ sym: Sym) -> ScopeRecord { return scope.record(self) }

  // MARK: TypeExpr

  func typeVal(scope: Scope, _ subj: String) -> Type {
    return syms.last!.typeValForTypeRecord(scope.record(self), subj)
  }
}

