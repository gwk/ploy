// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


protocol SubForm: TextTreeStreamable {
  init(form: Form, subj: String)
  var form: Form { get }
}

extension SubForm {
  var syn: Syn { return form.syn }
  var textTreeHead: String { return form.textTreeHead }
  var textTreeChildren: [Any] { return form.textTreeChildren }
}
