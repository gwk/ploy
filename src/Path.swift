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

  func typeForExpr(ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let record = scope.record(path: self)
    let type = syms.last!.typeForExprRecord(scope.record(path: self))
    ctx.trackExpr(self, type: type)
    ctx.pathRecords[self] = record
    return type
  }

  func compileExpr(ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    syms.last!.compileSym(em, depth, ctx.pathRecords[self]!, isTail: isTail)
  }

  // MARK: Identifier

  var name: String { return syms.map({$0.name}).joinWithSeparator("/") }
  
  func record(scope: Scope, _ sym: Sym) -> ScopeRecord { return scope.record(path: self) }

  // MARK: TypeExpr

  func typeForTypeExpr(scope: Scope, _ subj: String) -> Type {
    return syms.last!.typeForTypeRecord(scope.record(path: self), subj)
  }
}

