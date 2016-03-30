// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Reify: _Form, TypeExpr { // type reification:  `T^A`.
  let callee: TypeExpr
  let arg: TypeExpr

  required init(_ syn: Syn, callee: TypeExpr, arg: TypeExpr) {
    self.callee = callee
    self.arg = arg
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return self.init(Syn(l.syn, r.syn),
      callee: castForm(l, "type reification", "type expression"),
      arg: castForm(r, "type reification", "type expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    callee.writeTo(&target, depth + 1)
    arg.writeTo(&target, depth + 1)
  }

  func typeForTypeExpr(scope: Scope, _ subj: String) -> Type {
    fatalError()
  }
}


/// type reification implied by adjacency to CmpdType: `T<A B>`.
class ReifyAdj: Reify {}
