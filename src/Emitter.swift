// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Emitter {
  let parent: Emitter?
  let file: OutFile
  var lines: [String] = []

  init(parent: Emitter?, file: OutFile) {
    self.parent = parent
    self.file = file
  }

  deinit {
    for line in lines {
      file.write(line)
      file.write("\n")
    }
  }

  func str(depth: Int, _ string: String) {
    lines.append(String(indent: depth) + string)
  }
  
  func append(string: String) {
    lines[lines.lastIndex!] = lines.last! + string
  }
}


func compileProgram(file: OutFile, hostPath: String, main: Do, ins: [In]) {
  let em = Emitter(parent: nil, file: file)
  em.str(0, "#!/usr/bin/env iojs")
  em.str(0, "\"use strict\";\n")
  em.str(0, "(function(){ // ploy.")
  em.str(0, "// host.js.\n")
  let host_src = InFile(path: hostPath).read()
  em.str(0, host_src)
  em.str(0, "")

  globalSpace.defineAllDefs(ins)
  
  em.str(0, "let _main = function(){ // main.")
  main.compileBody(em, 1, globalSpace.makeChild(), typeInt, isTail: true)
  em.append("};")
  
  for space in globalSpace.spaces {
    if space.usedDefs.isEmpty {
      continue
    }
    em.str(0, "\n// in \(space.name).")
    for def in space.usedDefs {
      def.compileDef(em, space)
      em.append(";")
    }
  }

  em.str(0, "\nPROC__exit(_tramp(_main()))})()")
}
