// Copyright © 2016 George King. Permission to use this file is granted in ploy/license.txt.


protocol SubForm {
  init(form: Form, subj: String)
  var form: Form { get }
}

extension SubForm {

  var syn: Syn { return form.syn }

  func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    form.write(to: &stream, depth)
  }
}


