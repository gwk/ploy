// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


class Emitter {
  let file: OutFile
  var lines: [String] = []

  init(file: OutFile) {
    self.file = file
  }

  deinit {
    if !lines.isEmpty {
      for line in lines {
        file.write(line)
        file.write("\n")
      }
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
  file.writeL("#!/usr/bin/env iojs")
  file.writeL("\"use strict\";\n")
  file.writeL("(function(){ // ploy.")
  file.writeL("// host.js.\n")
  let host_src = try! InFile(path: hostPath).readText()
  file.writeL(host_src)
  file.writeL("")

  let globalSpace = Space(pathNames: ["ROOT"], parent: nil, file: file)

  globalSpace.setupGlobal(ins)
  
  file.writeL("let _main = function(){ // main.")
  let ctx = TypeCtx()
  main.compileBody(ctx, LocalScope(parent: globalSpace, em: globalSpace.makeEm()), 1, isTail: true)
  // emitter gets flushed here when it gets released.
  file.writeL("};")
  file.writeL("\nPROC__exit(_tramp(_main()))})()")
}
