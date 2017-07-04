// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class ImplicitVoid: Form { // the implied expression in an empty body.

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
  }
}
