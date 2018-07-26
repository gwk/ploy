// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


enum Clause: VaryingForm { // `?` case or `/` default.

  case case_(Case)
  case default_(Default)

  static func accept(_ actForm: ActForm) -> Clause? {
    switch actForm {
    case let f as Case:     return .case_(f)
    case let f as Default:  return .default_(f)
    default: return nil
    }
  }

  var actForm: ActForm {
    switch self {
    case .case_(let case_): return case_
    case .default_(let default_): return default_
    }
  }

  static var expDesc: String { return "case (`cond ? expr`) or default (`/ expr`) clause" }
}
