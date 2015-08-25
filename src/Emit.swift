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


func compileProgram(file: OutFile, hostPath: String, main: Do, ins: [In]) {
  let em = Emit()
  em.str(0, "#!/usr/bin/env iojs")
  em.str(0, "\"use strict\";\n")
  em.str(0, "(function(){ // ploy.")
  em.str(0, "// host.js.\n")
  let host_src = InFile(path: hostPath).read()
  em.str(0, host_src)
  em.str(0, "")
  
  for i in ins {
    let space = global.getOrCreateSpace([i.sym])
    i.defineDefs(space)
  }
  
  let mainScope = Scope(pathNames: [], parent: global)
  em.str(0, "let _main = function(){ // main.")
  main.compileBody(em, 0, mainScope, typeInt)
  em.append("};")
  
  for space in global.spaces {
    if space.usedDefs.isEmpty {
      continue
    }
    em.str(0, "\n// in \(space.name).")
    for def in space.usedDefs {
      def.compileDef(em, space)
      em.append(";")
    }
  }

  em.str(0, "\nPROC__exit(_main())})()")

  for l in em.lines {
    file.write(l)
    file.write("\n")
  }
}
