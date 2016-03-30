// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sig: _Form, TypeExpr { // function signature: `Par%Ret`.
  let par: TypeExpr // TODO: rename input.
  let ret: TypeExpr

  init(_ syn: Syn, par: TypeExpr, ret: TypeExpr) {
    self.par = par
    self.ret = ret
    super.init(syn)
  }

  static func mk(l: Form, _ r: Form) -> Form {
    return Sig(Syn(l.syn, r.syn),
      par: castForm(l, "signature parameter", "type expression"),
      ret: castForm(r, "signature return", "type expression"))
  }
  
  override func writeTo<Target : OutputStream>(inout target: Target, _ depth: Int) {
    writeHead(&target, depth, "\n")
    par.writeTo(&target, depth + 1)
    ret.writeTo(&target, depth + 1)
  }

  func typeForTypeExpr(scope: Scope, _ subj: String) -> Type {
    return Type.Sig(par: par.typeForTypeExpr(scope, "signature input"), ret: ret.typeForTypeExpr(scope, "signature return"))
  }
}

