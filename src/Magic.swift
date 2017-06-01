// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Magic: Form { // synthesized code.

  let type: Type
  let code: String

  init(_ syn: Syn, type: Type, code: String) {
    self.type = type
    self.code = code
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, ": type: \(type); code: `\(code)`")
  }
}
