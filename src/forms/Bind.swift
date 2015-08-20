// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Bind: _Form, Stmt, Def { // value binding: `name=expr`.
  let sym: Sym
  let val: Expr
  
  init(_ syn: Syn, sym: Sym, val: Expr) {
    self.sym = sym
    self.val = val
    super.init(syn)
  }
  
  static func mk(l: Form, _ r: Form) -> Form {
    return Bind(Syn(l.syn, r.syn),
      sym: castForm(l, "binding", ""),
      val: castForm(r, "binding", ""))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    sym.writeTo(&target, depth + 1)
    val.writeTo(&target, depth + 1)
  }
  
  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    fatalError()
    return typeVoid
  }
  
  func scopeRecKind(scope: Scope) -> ScopeRec.Kind {
    if let ann = val as? Ann {
      return .Lazy(ann.type.typeVal(scope, "type annnotation"))
    } else {
      val.fail("syntax error", "definition requires explicit type annotation")
    }
  }
}

