// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


class Emitter {
  let file: OutFile
  var lines: [String] = []

  deinit {
    assert(lines.isEmpty, "lines is not empty")
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
  // normal hash bang line (commented below) cannot pass necessary flags to node,
  // because hashbang only respects one argument.
  // file.writeL("#!/usr/bin/env node")

  // instead, launch as shell script, then immediately exec env with all arguments.
  // the hack relies on sh and node both interpreting the line;
  // node sees a string followed by a comment;
  // sh sees the no-op ':' command followed by the exec command.
  file.writeL("#!/bin/sh")
  file.writeL("':' //; exec /usr/bin/env node --harmony-tailcalls \"$0\" \"$@\"\n")

  file.writeL("\"use strict\";\n")
  file.writeL("(function(){ // ploy.")
  file.writeL("// host.js.")
  let host_src = guarded { try String(contentsOfFile: hostPath) }
  file.writeL(host_src)
  file.writeL("// host.js END.\n")

  let rootSpace = Space(pathNames: ["ROOT"], parent: nil, file: file)
  let mainSpace = rootSpace.setupRoot(ins: ins, mainIn: mainIn)
  let mainRecord = mainSpace.compileMain(mainIn: mainIn)

  file.writeL("\n\(mainRecord.hostName)()})()")
}
