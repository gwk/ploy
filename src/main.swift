// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


let usageMsg = "usage: lib-src-paths… -mapper mapper-path -main main-src-path -o out-path."

let validOpts = Set([
  "-mapper",
  "-main",
  "-o",
])


func main() {
  var ployPath: Path! = nil
  var srcPaths: [Path] = []
  var opts: [String: String] = [:]

  var opt: String? = nil
  for (i, arg) in processArguments.enumerated() {
    if i == 0 {
      ployPath = Path(arg)
    } else if let o = opt {
      opts[o] = arg
      opt = nil
    } else if validOpts.contains(arg) {
      opt = arg
    } else if arg.hasPrefix("-") {
      fail("unrecognized option: '\(arg)'")
    } else {
      srcPaths.append(Path(arg))
    }
  }
  _ = ployPath

  check(opt == nil, "dangling option flag: '\(opt!)'")

  for (key, val) in processEnvironment {
    if key == "PLOY_DBG_METHODS" {
      globalDbgMethodCtxNames = Set(val.split(" "))
      errL("PLOY_DBG_METHODS: ", globalDbgMethodCtxNames)
    }
  }

  guard let mapperPath = Path(opts["-mapper"]) else { fail("`-mapper mapper-path` argument is required.") }
  guard let mainPath = Path(opts["-main"]) else { fail("`-main main-src-path` argument is required.") }
  guard let outPath = Path(opts["-o"]) else { fail("`-o out-path` argument is required.") }

  var libPaths: [Path] = []
  var incPaths: [Path] = []

  let known_methods = Set([".ploy", ".js", ""])
  for path in srcPaths {
    if !known_methods.contains(path.ext) {
      fail("invalid method for path: \(path)")
    }
  }
  let allSrcPaths = guarded { try walkPaths(roots: srcPaths) }
  for path in allSrcPaths {
    let ext = path.ext
    if ext == ".ploy" {
      libPaths.append(path)
    } else if ext == ".js" {
      incPaths.append(path)
    }
  }

  let mainDefs = parsePloy(path: mainPath)
  let libDefs = libPaths.flatMap { parsePloy(path: $0) }

  let tmpPath = outPath.append(".tmp")
  let mapPath = outPath.append(".srcmap")

  let tmpFile = guarded { try File(path: tmpPath, mode: .write, create: 0o644) }

  let mapPipe = Pipe()
  let mapSend = mapPipe.fileHandleForWriting
  let mapProc = Process()
  mapProc.launchPath = mapperPath.expandUser
  mapProc.arguments = [outPath.expandUser, mapPath.expandUser]
  mapProc.standardInput = mapPipe.fileHandleForReading
  mapProc.standardOutput = FileHandle.standardError
  mapProc.standardError = FileHandle.standardError
  mapProc.launch()

  let (rootSpace, mainSpace) = setupRootAndMain(mainPath: mainPath, outFile: tmpFile, mapSend: mapSend)

  mainSpace.add(defs: mainDefs, root: rootSpace)
  _ = mainSpace.getMainDef() // check that we have `main` before doing additional work.
  mainSpace.add(defs: libDefs, root: rootSpace)

  compileProgram(mainPath: mainPath, includePaths: incPaths, mainSpace: mainSpace, mapPath: mapPath)

  renameFile(from: tmpPath, to: outPath)
  do {
    try File.changePerms(path: outPath, perms: 0o755)
  } catch let e {
    fail("could not set compiled output file to executable: \(outPath)\n  \(e)")
  }
  mapSend.closeFile() // closing the pipe to gen-source-map causes the map file to be written.
  mapProc.waitUntilExit()
  if mapProc.terminationStatus != 0 {
    fail("gen-source-map subprocess failed.")
  }
}

main()
