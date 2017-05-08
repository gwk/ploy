// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Clause: SubForm { // either a `?` case or `/` default.

  case case_(Case)
  case default_(Default)

  init(form: Form, subj: String) {
    switch form {
    case let f as Case:     self = .case_(f)
    case let f as Default:  self = .default_(f)
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
