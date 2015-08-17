// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.


let usageMsg = "usage: module-src-paths… -main main-src-path -o out-path."

let validOpts = Set([
  "-main",
  "-o",
])

var ployPath: String! = nil
var hostPath: String! = nil
var modulePaths: [String] = []
var opts: [String: String] = [:]

var opt: String? = nil
for (i, arg) in Process.arguments.enumerate() {
  if i == 0 {
    ployPath = arg
  } else if let o = opt {
    opts[o] = arg
    opt = nil
  } else if validOpts.contains(arg) {
    opt = arg
  } else if arg.hasPrefix("-") {
    fail("unrecognized option: '\(arg)'")
  } else {
    if let hostDir = arg.beforeSuffix("host.ploy") {
      hostPath = hostDir + "host.js"
    }
    modulePaths.append(arg)
  }
}

check(opt == nil, "dangling option flag: '\(opt)'")
check(hostPath != nil, "host.ploy must be specified in the modules list.")

guard let mainPath = opts["-main"] else { fail("-main main-src-path argument is required.") }
guard let outPath = opts["-o"] else { fail("-o out-path argument is required.") }

let tmpPath = outPath + ".tmp"
let tmpFile = OutFile(path: tmpPath, create: 0o644)

let main = Src(path: mainPath).parseMain(verbose: false)

let modules = modulePaths.flatMap { Src(path: $0).parseModule(verbose: false) }

emitProgram(tmpFile, hostPath: hostPath, main: main, ins: modules)

copy(fromPath: tmpPath, toPath: outPath, create: 0o644)
File.setPerms(outPath, 0o755)
