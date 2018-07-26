// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Expand: ActFormBase, ActForm { // compound macro expansion argument: `[a b]`.
  let pars: [Expr]

  init(_ syn: Syn, pars: [Expr]) {
    self.pars = pars
    super.init(syn)
  }

  static var expDesc: String { return "`[…]` expand form" }

  var textTreeChildren: [Any] { return pars }

  func compileExpand(depth: Int, _ scope: LocalScope) -> Type {
    fatalError()
  }
}

