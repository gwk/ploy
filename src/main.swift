// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.


var outPath = ""
var mainPath = ""
var modulePaths: [String] = []


check(Process.arguments.count >= 3, "usage: output_path, main_src_path, module_paths….")

for (i, arg) in Process.arguments.enumerate() {
  switch i {
  case 0: continue // program name.
  case 1: outPath = arg
  case 2: mainPath = arg
  default: modulePaths.append(arg)
  }
}

let tmpPath = outPath + ".tmp"
let tmpFile = OutFile(path: tmpPath, create: 0o666)

let mainSyn = parseFileAtPath(mainPath)
let main = compileMain(mainSyn)

let modules = modulePaths.map {
  (path: String) -> Module in
  let syn = parseFileAtPath(path)
  return compileModule(syn)
}

emitProgram(tmpFile, main: main, modules: modules)

copy(fromPath: tmpPath, toPath: outPath, create: 0o777)
