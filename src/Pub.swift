// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Pub: ActFormBase, ActForm { // public modifier: `pub expr;`.
  let def: Def

  init(_ syn: Syn, def: Def) {
    self.def = def
    super.init(syn)
  }

  static var expDesc: String { return "`pub`" }

  var textTreeChildren: [Any] { return [def] }
}

