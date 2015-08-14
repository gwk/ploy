// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: _Form, TypeExpr { // function signature: `Par%Ret`.
  let par: TypeExpr
  let ret: TypeExpr

  init(_ syn: Syn, par: TypeExpr, ret: TypeExpr) {
    self.par = par
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Sig(Syn(l.syn, r.syn),
      par: castForm(l, "signature", "type expression"),
      ret: castForm(r, "signature", "type expression"))
  }
  
  override func writeTo<Target : OutputStreamType>(inout target: Target, _ depth: Int) {
    super.writeTo(&target, depth)
    par.writeTo(&target, depth + 1)
    ret.writeTo(&target, depth + 1)
  }
}

