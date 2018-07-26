// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class ImplicitVoid: ActFormBase, ActForm { // the implied expression in an empty body.

  static var expDesc: String { return "implicit void" }

  var textTreeChildren: [Any] { return [] }
}
