// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Darwin


class Form: Hashable, CustomStringConvertible {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }

  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String {
    var s = ""
    writeHead(to: &s, 0, "")
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

  func write<Stream: TextOutputStream>(to stream: inout Stream, _ depth: Int) { fatalError() }

  func writeHead<Stream: TextOutputStream>(to stream: inout Stream, _ depth: Int, _ suffix: String = "\n") {
    stream.write(String(indent: depth))
    stream.write(String(describing: type(of: self)))
    stream.write(" ")
    stream.write(String(describing: syn))
    stream.write(suffix)
  }

  func failForm(prefix: String, msg: String, notes: [(Form?, String)] = []) -> Never {
    syn.src.errPos(syn.pos, end: syn.visEnd, prefix: prefix, msg: msg)
    for (form, msg) in notes {
      if let form = form {
        form.syn.src.errPos(form.syn.pos, end: form.syn.visEnd, prefix: "note", msg: msg)
      }
    }
    exit(1)
  }

  func failForm(prefix: String, msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: prefix, msg: msg, notes: notes)
  }

  func failSyntax(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "syntax error", msg: msg, notes: notes)
  }

  func failType(_ msg: String, notes: (Form?, String)...) -> Never {
    failForm(prefix: "type error", msg: msg, notes: notes)
  }
}


func ==(l: Form, r: Form) -> Bool { return l === r }


/// castForm uses return type polymorphism to implicitly choose the protocol to cast to.
func castForm<T: Form>(_ form: Form, _ subj: String, _ exp: String) -> T {
  if let form = form as? T {
    return form
  } else {
    form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
}
