// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


protocol Form: CustomStringConvertible, CustomDebugStringConvertible, TextTreeStreamable {
  // A syntactic Form, either an ActForm or else a VaryingForm enum wrapping an ActForm.

  static var expDesc: String { get } // Display description of possible form contents, e.g. "case or default clause".

  var actForm: ActForm { get } // The actual underlying ActForm.

  var syn: Syn { get }

  static func accept(_ actForm: ActForm) -> Self?
}


extension Form {

  // TextTreeStreamable.

  var textTreeHead: String { return description }

  // Form.

  var actDesc: String { return type(of: actForm).expDesc }

  static func expect(_ actForm: ActForm, subj: String, exp: String? = nil) -> Self {
    if let e = Self.accept(actForm) { return e }
    actForm.failSyntax("\(subj) expected \(exp ?? Self.expDesc); received \(actForm.actDesc).")
  }

  func failForm(prefix: String, msg: String, notes: [(Form?, String)] = []) -> Never {
    syn.errDiagnostic(prefix: prefix, msg: msg)
    for (form, msg) in notes {
      if let form = form {
        form.syn.errDiagnostic(prefix: "note", msg: msg)
      }
    }
    exit(1)
  }

  func failSyntax(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "syntax error", msg: msg, notes: notes)
  }

  func failType(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "type error", msg: msg, notes: notes)
  }

  func failScope(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "scope error", msg: msg, notes: notes)
  }

  func fatal(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "PLOY COMPILER ERROR", msg: msg, notes: notes)
  }
}
