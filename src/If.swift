// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class If: Form { // if statement: `if cases… default;`.
  let cases: [Case]
  let dflt: Default?

  init(_ syn: Syn, cases: [Case], dflt: Default?) {
    self.cases = cases
    self.dflt = dflt
    super.init(syn)
  }

  override func write<Stream : TextOutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth)
    for c in cases {
      c.write(to: &stream, depth + 1)
    }
    if let dflt = dflt {
      dflt.write(to: &stream, depth + 1)
    }
  }
}

