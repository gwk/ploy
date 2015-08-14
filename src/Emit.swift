// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Emit {
  var lines: [String] = []
  
  func str(depth: Int, _ string: String) {
    lines.append(String(indent: depth) + string)
  }
  
  func append(string: String) {
    lines[lines.lastIndex!] = lines.last! + string
  }
}


func emitProgram(file: OutFile, hostPath: String, main: Do, ins: [In]) {
  let em = Emit()
  em.str(0, "#!/usr/bin/env iojs")
  em.str(0, "\"use strict\";\n")
  em.str(0, "function() { // ploy namespace.")
  em.str(0, "// host.js.\n")
  let host_src = InFile(path: hostPath).read()
  em.str(0, host_src)
  em.str(0, "")

  for i in ins {
    em.str(0, "// in \(i.name.string)")
    i.emit(em, 0)
    em.str(0, "")
  }
  main.emit(em, 0)
  em.str(0, "}()")

  for l in em.lines {
    file.write(l)
    file.write("\n")
  }
}
