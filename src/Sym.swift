// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Sym: Form { // symbol: `name`.
  let name: String

  init(_ syn: Syn, name: String) {
    self.name = name
    super.init(syn)
  }

  override var description: String {
    return "\(type(of: self)):\(syn): \(name)"
  }

  override var textTreeChildren: [Any] { return [] }

  // MARK: Sym

  var hostName: String { return name }

  var cloned: Sym { return Sym(syn, name: name) }

  func failUndef() -> Never {
    failScope("`\(name)` is not defined in this scope.")
  }

  func failRedef(original: Sym?) -> Never {
    failScope("redefinition of `\(name)`", notes: (original, "original definition here:"))
  }
}
