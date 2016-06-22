// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Path: _Form, Expr, Identifier, TypeExpr { // path: `LIB/name`.
  let syms: [Sym]
  
  init(_ syn: Syn, syms: [Sym]) {
    check(syms.count > 0)
    self.syms = syms
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": ")
    var first = true
    for s in syms {
      if first {
        first = false
      } else {
        stream.write("/")
      }
      stream.write(s.name)
    }
    stream.write("\n")
  }

  // MARK: Expr

  func typeForExpr(_ ctx: TypeCtx, _ scope: LocalScope) -> Type {
    let record = scope.record(path: self)
    let type = syms.last!.typeForExprRecord(scope.record(path: self))
    ctx.trackExpr(self, type: type)
    ctx.pathRecords[self] = record
    return type
  }

  func compileExpr(_ ctx: TypeCtx, _ em: Emitter, _ depth: Int, isTail: Bool) {
    ctx.assertIsTracking(self)
    syms.last!.compileSym(em, depth, ctx.pathRecords[self]!, isTail: isTail)
  }

  // MARK: Identifier

  var name: String { return syms.map({$0.name}).joined(separator: "/") }
  
  func record(_ scope: Scope, _ sym: Sym) -> ScopeRecord { return scope.record(path: self) }

  // MARK: TypeExpr

  func typeForTypeExpr(_ scope: Scope, _ subj: String) -> Type {
    return syms.last!.typeForTypeRecord(scope.record(path: self), subj)
  }
}

