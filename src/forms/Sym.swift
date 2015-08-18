// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Expr, TypeExpr { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(name)
    target.write("\n")
  }

  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    let rec = scope.getRec(self)
    switch rec.kind {
    case .Type: return rec.typeVal
    default: fail("scope error", "\(subj) expected a type; `\(name)` refers to a value.")
    }
  }

  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    let rec = scope.getRec(self)
    switch rec.kind {
    case .Val: em.str(depth, name)
    case .Lazy: em.str(depth, "\(name)__acc()")
    case .Type: fail("scope error", "expected a value; `\(name)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    if !expType.accepts(rec.typeVal) {
      fail("type error", "expected type `\(expType)`; `\(name)` has type `\(rec.typeVal)`")
    }
    return rec.typeVal
  }

  @noreturn func failUndef() { fail("scope error", "`\(name)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    fail("scope error", "redefinition of `\(name)`", original.map { ($0, "original definition here") })
  }
}

