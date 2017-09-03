// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class TypeVar: Form { // tag: `^T`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  override var textTreeChildren: [Any] { return [sym] }
}

