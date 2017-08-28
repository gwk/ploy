// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


class Form: Hashable, CustomStringConvertible, TextOutputStreamable {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }

  static func ==(l: Form, r: Form) -> Bool { return l === r }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String {
    var s = ""
    writeHead(to: &s, 0, suffix: "")
    return s
  }

  var syntaxName: String { return String(describing: type(of: self)) }

  var fullDesc: String {
    var s = ""
    write(to: &s, 0)
    return s
  }

  func write<Stream : TextOutputStream>(to stream: inout Stream) {
    write(to: &stream, 0)
  }

  func write<Stream: TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    fatalError("Form.write not implemented for type: \(type(of: self))")
  }

  func writeHead<Stream: TextOutputStream>(to stream: inout Stream, _ depth: Int, suffix: String = "\n") {
    stream.write(String(indent: depth))
    stream.write(String(describing: type(of: self)))
    stream.write(":")
    stream.write(String(describing: syn))
    stream.write(suffix)
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
