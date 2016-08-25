// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class LitStr: Form { // string literal: `'hi', "hi"`.
  let val: String

  init(_ syn: Syn, val: String) {
    self.val = val
    super.init(syn)
  }
  
  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": \"\(val)\"\n") // TODO: use source string.
  }
}


