// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: _Form, Expr, TypeExpr { // symbol: `name`.
  let string: String

  init(_ syn: Syn, string: String) {
    self.string = string
    super.init(syn)
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    target.write(String(indent: depth))
    target.write(String(self.dynamicType))
    target.write(" ")
    target.write(String(syn))
    target.write(": ")
    target.write(string)
    target.write("\n")
  }

  func typeVal(scope: Scope, _ subj: String) -> TypeVal {
    let rec = scope.getRec(self)
    switch rec.kind {
    case .Type: return rec.typeVal
    default: fail("scope error", "\(subj) expected a type; `\(string)` refers to a value.")
    }
  }

  override func compile(em: Emit, _ depth: Int, _ scope: Scope, _ expType: TypeVal) -> TypeVal {
    let rec = scope.getRec(self)
    switch rec.kind {
    case .Val: em.str(depth, string)
    case .Lazy: em.str(depth, "\(string)__acc()")
    case .Type: fail("scope error", "expected a value; `\(string)` refers to a type.") // TODO: eventually this will return a runtime type.
    }
    return rec.typeVal
  }

  @noreturn func failUndef() { fail("scope error", "`\(string)` is not defined in this scope") }
  
  @noreturn func failRedef(original: Sym?) {
    fail("scope error", "redefinition of `\(string)`", original.map { ($0, "original definition here") })
  }
}

