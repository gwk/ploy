// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Tag: ActFormBase, ActForm { // tag: `-X`.
  let sym: Sym

  init(_ syn: Syn, sym: Sym) {
    self.sym = sym
    super.init(syn)
  }

  static var expDesc: String { return "`-…` tag" }

  var textTreeChildren: [Any] { return [sym] }

  // Tag.

  var cloned: Tag { return Tag(syn, sym: sym.cloned) }
}

