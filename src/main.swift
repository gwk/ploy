// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


let usageMsg = "usage: lib-src-paths… -main main-src-path -o out-path."

let validOpts = Set([
  "-main",
  "-o",
])


func main() {
  var ployPath: String! = nil
  var includePaths: [String] = []
  var libPaths: [String] = []
  var opts: [String: String] = [:]

  var opt: String? = nil
  for (i, arg) in processArguments.enumerated() {
    if i == 0 {
      ployPath = arg
    } else if let o = opt {
      opts[o] = arg
      opt = nil
    } else if validOpts.contains(arg) {
      opt = arg
    } else if arg.hasPrefix("-") {
      fail("unrecognized option: '\(arg)'")
    } else if arg.pathExt == ".js" {
      includePaths.append(arg)
    } else if arg.pathExt == ".ploy" {
      libPaths.append(arg)
    } else {
      fail("invalid path extension: '\(arg)'")
    }
  }
  let _ = ployPath

  check(opt == nil, "dangling option flag: '\(opt)'")

  guard let mainPath = opts["-main"] else { fail("`-main main-src-path` argument is required.") }
  guard let outPath = opts["-o"] else { fail("`-o out-path` argument is required.") }

  let tmpPath = outPath + ".tmp"
  let tmpFile = guarded { try OutFile(path: tmpPath, create: 0o644) }

  let (mainIns, mainIn) = Src(path: mainPath).parseMain(verbose: false)

  let ins = mainIns + libPaths.flatMap { Src(path: $0).parseLib(verbose: false) }

  compileProgram(file: tmpFile, includePaths: includePaths, ins: ins, mainIn: mainIn)

  renameFileAtPath(tmpPath, toPath: outPath)
  do {
    try File.changePerms(outPath, 0o755)
  } catch let e {
    fail("error: could not set compiled output file to executable: \(outPath)\n  \(e)")
  }
}

main()
