// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class CmpdType: Form { // compound type: `<A B>`.
  let pars: [Par]

  init(_ syn: Syn, pars: [Par]) {
    self.pars = pars
    super.init(syn)
  }

  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, pars.isEmpty ? " <>\n" : "\n")
    for p in pars {
      p.write(to: &stream, depth + 1)
    }
  }
}

