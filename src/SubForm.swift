// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


protocol SubForm: TextTreeStreamable {
  init?(form: Form)
  var form: Form { get }
  static var parseExpDesc: String { get }
}

extension SubForm {
  var syn: Syn { return form.syn }
  var textTreeHead: String { return form.textTreeHead }
  var textTreeChildren: [Any] { return form.textTreeChildren }

  init(form: Form, subj: String) {
    guard let s = Self(form: form) else {
      form.failSyntax("\(subj) expected \(Self.parseExpDesc); received \(form.syntaxName).")
    }
    self = s
  }
}
