// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Clause: SubForm {

  case case_(Case)
  case default_(Default)

  init(form: Form, subj: String) {
    switch form {
    case let form as Case:    self = .case_(form)
    case let form as Default: self = .default_(form)
    default:
      form.failSyntax("\(subj) expects case (`cond ? expr`) or default (`/ expr`) but received \(form.syntaxName).")
    }
  }

  var form: Form {
    switch self {
      case .case_(let case_): return case_
      case .default_(let default_): return default_
    }
  }
}
