// Copyright © 2017 George King. Permission to use this file is granted in ploy/license.txt.


class Tag: Form { // tag: `-X`.
  let tagged: Tagged

  init(_ syn: Syn, tagged: Tagged) {
    self.tagged = tagged
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    tagged.write(to: &stream, depth + 1)
  }
}

