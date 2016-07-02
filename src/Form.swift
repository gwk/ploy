// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Form: Hashable, CustomStringConvertible {
  let syn: Syn
  init(_ syn: Syn) { self.syn = syn }
  
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  var description: String {
    var s = ""
    writeHead(to: &s, 0, "")
    return s
  }

  var syntaxName: String { return String(self.dynamicType) }

  var fullDesc: String {
    var s = ""
    write(to: &s, 0)
    return s
  }

  func write<Stream : OutputStream>(to stream: inout Stream) {
    write(to: &stream, 0)
  }

  func write<Stream: OutputStream>(to stream: inout Stream, _ depth: Int) { fatalError() }

  func writeHead<Stream: OutputStream>(to stream: inout Stream, _ depth: Int, _ suffix: String) {
    stream.write(String(indent: depth))
    stream.write(String(self.dynamicType))
    stream.write(" ")
    stream.write(String(syn))
    stream.write(suffix)
  }

  @noreturn func failForm(prefix: String, msg: String, notes: [(Form?, String)] = []) {
    syn.src.errPos(syn.pos, end: syn.visEnd, prefix: prefix, msg: msg)
    for (form, msg) in notes {
      if let form = form {
        form.syn.src.errPos(form.syn.pos, end: form.syn.visEnd, prefix: "note", msg: msg)
      }
    }
    Process.exit(1)
  }

  @noreturn func failForm(prefix: String, msg: String, notes: (Form?, String)...) {
    failForm(prefix: prefix, msg: msg, notes: notes)
  }

  @noreturn func failSyntax(_ msg: String, notes: (Form?, String)...) {
    failForm(prefix: "syntax error", msg: msg, notes: notes)
  }

  @noreturn func failType(_ msg: String, notes: (Form?, String)...) {
    failForm(prefix: "type error", msg: msg, notes: notes)
  }
}


func ==(l: Form, r: Form) -> Bool { return l === r }


/// castForm uses return type polymorphism to implicitly choose the protocol to cast to.
@warn_unused_result
func castForm<T>(_ form: Form, _ subj: String, _ exp: String) -> T {
  // note: seems that should be able to parameterize as <T: Form> but swift 2.2 does not like that.
  if let form = form as? T {
    return form
  } else {
    form.failSyntax("\(subj) expects \(exp) but received \(form.syntaxName).")
  }
}

