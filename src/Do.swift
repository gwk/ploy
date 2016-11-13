// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Do: Form { // do block: `{…}`.
  let body: Body

  init(_ syn: Syn, body: Body) {
    self.body = body
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, "\n")
    body.write(to: &stream, depth + 1)
  }
}
