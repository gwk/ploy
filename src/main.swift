// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


var outPath = ""
var mainPath = ""
var modulePaths: [String] = []
var hostPath = ""

check(Process.arguments.count >= 3, "usage: output_path, main_src_path, module_paths….")

for (i, arg) in Process.arguments.enumerate() {
  switch i {
  case 0: continue // program name.
  case 1: outPath = arg
  case 2: mainPath = arg
  default:
    if let hostDir = arg.beforeSuffix("host.ploy") {
      hostPath = hostDir + "host.js"
    }
    modulePaths.append(arg)
  }
}

check(hostPath.characters.count > 0, "host.ploy must be specified in the modules list")

let tmpPath = outPath + ".tmp"
let tmpFile = OutFile(path: tmpPath, create: 0o666)

let main = Src(path: mainPath).parseMain(verbose: true)

let modules = modulePaths.flatMap { Src(path: $0).parseModule(verbose: true) }

emitProgram(tmpFile, hostPath: hostPath, main: main, ins: modules)

copy(fromPath: tmpPath, toPath: outPath, create: 0o777)
