// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVar: ActFormBase, ActForm { // tag: `^T`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  static var expDesc: String { return "`^…` type variable" }

  var textTreeChildren: [Any] { return [sym] }
}

