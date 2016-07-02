// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class In: Form { // in statement: `in module-name statements…;`.
  let identifier: Identifier? // main In does not have an identifier.
  let defs: [Def]

  init(_ syn: Syn, identifier: Identifier?, defs: [Def]) {
    self.identifier = identifier
    self.defs = defs
    super.init(syn)
  }
  
  override func write<Stream : OutputStream>(to stream: inout Stream, _ depth: Int) {
    writeHead(to: &stream, depth, (identifier == nil) ? " MAIN\n" : "\n")
    if let identifier = identifier {
      identifier.form.write(to: &stream, depth + 1)
    }
    for d in defs {
      d.form.write(to: &stream, depth + 1)
    }
  }
}
