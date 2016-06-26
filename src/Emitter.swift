// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class Emitter {
  let file: OutFile
  var lines: [String] = []

  deinit {
    assert(lines.isEmpty)
  }
  
  init(file: OutFile) {
    self.file = file
  }

  func flush() {
    if !lines.isEmpty {
      for line in lines {
        file.write(line)
        file.write("\n")
      }
      file.write("\n")
      lines.removeAll()
    }
  }

  func str(_ depth: Int, _ string: String) {
    lines.append(String(indent: depth) + string)
  }
  
  func append(_ string: String) {
    lines[lines.lastIndex!] = lines.last! + string
  }
}


func compileProgram(file: OutFile, hostPath: String, ins: [In], mainIn: In) {
  file.writeL("#!/usr/bin/env node")
  file.writeL("\"use strict\";\n")
  file.writeL("(function(){ // ploy.")
  file.writeL("// host.js.")
  let host_src = try! InFile(path: hostPath).readText()
  file.writeL(host_src)
  file.writeL("// host.js END.\n")

  let rootSpace = Space(pathNames: ["ROOT"], parent: nil, file: file)
  let mainSpace = rootSpace.setupRoot(ins: ins, mainIn: mainIn)
  let mainRecord = mainSpace.compileMain(mainIn: mainIn)

  // call the main function via the tail recursion trampoline, and pass the return code to PROC/exit.
  file.writeL("\nPROC__exit(_tramp(\(mainRecord.hostName)()))})()")
}
