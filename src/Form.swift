// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


class Form: Hashable, CustomStringConvertible, TextTreeStreamable {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }

  static func ==(l: Form, r: Form) -> Bool { return l === r }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String { return "\(type(of: self)):\(syn)" }

  var textTreeHead: String { return description }

  var textTreeChildren: [Any] { fatalError("textTreeChildren not implemented for type: \(type(of: self))") }

  var syntaxName: String { return String(describing: type(of: self)) }

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
