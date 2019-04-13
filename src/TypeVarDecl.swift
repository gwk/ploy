// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVarDecl: ActFormBase, ActForm { // type var declaration: `^T`.
  let sym: Sym

  required init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  static var expDesc: String { return "`^` typevar declaration" }

  var textTreeChildren: [Any] { return [sym] }
}
