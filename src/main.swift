// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Quilt


let usageMsg = "usage: lib-src-paths… -main main-src-path -o out-path."

let validOpts = Set([
  "-main",
  "-o",
])


func main() {
  var ployPath: String! = nil
  var srcPaths: [String] = []
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
    } else {
      srcPaths.append(arg)
    }
  }
  _ = ployPath

  check(opt == nil, "dangling option flag: '\(opt)'")

  guard let mainPath = opts["-main"] else { fail("`-main main-src-path` argument is required.") }
  guard let outPath = opts["-o"] else { fail("`-o out-path` argument is required.") }

  var libPaths: [String] = []
  var incPaths: [String] = []

  let known_exts = Set([".ploy", ".js", ""])
  for path in srcPaths {
    let ext = path.pathExt
    if !known_exts.contains(ext) {
      fail("invalid path extension: '\(path)'")
    }
  }
  let allSrcPaths = guarded { try walkPaths(roots: srcPaths) }
  for path in allSrcPaths {
    let ext = path.pathExt
    if ext == ".ploy" {
      libPaths.append(path)
    } else if ext == ".js" {
      incPaths.append(path)
    }
  }

  let mainDefs = Src(path: mainPath).parse(verbose: false)
  let libDefs = libPaths.flatMap { Src(path: $0).parse(verbose: false) }

  let tmpPath = outPath + ".tmp"
  let tmpFile = guarded { try OutFile(path: tmpPath, create: 0o644) }

  let (rootSpace, mainSpace) = setupRootAndMain(mainPath: mainPath, outFile: tmpFile)

  mainSpace.add(defs: mainDefs, root: rootSpace)
  _ = mainSpace.getMainDef() // check that we have `main` before doing additional work.
  mainSpace.add(defs: libDefs, root: rootSpace)

  compileProgram(file: tmpFile, includePaths: incPaths, mainSpace: mainSpace)

  renameFileAtPath(tmpPath, toPath: outPath)
  do {
    try File.changePerms(outPath, 0o755)
  } catch let e {
    fail("error: could not set compiled output file to executable: \(outPath)\n  \(e)")
  }
}

main()
