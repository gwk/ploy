// Copyright © 2015 George King. Permission to use this file is granted in ploy/license.txt.

import Foundation


let usageMsg = """
Ploy compiler usage:

ploy build lib-src-paths… -mapper mapper-path -main main-src-path -o out-path.

ploy test-types src-type dst-type
"""


let validBuildOpts = Set([
  "-mapper",
  "-main",
  "-o",
])


func main() {

  if processArguments.count < 2 { fail(usageMsg) }

  let args = Array(processArguments[2...])

  switch processArguments[1] {
  case "build": ploy_build(args: args)
  case "test-types": ploy_test_types(args: args)
  default: fail(usageMsg)
  }
}


func ploy_build(args:[String]) {
  var srcPaths: [Path] = []
  var opts: [String: String] = [:]

  var opt: String? = nil
  for arg in args {
    if let o = opt {
      opts[o] = arg
      opt = nil
    } else if validBuildOpts.contains(arg) {
      opt = arg
    } else if arg.hasPrefix("-") {
      fail("unrecognized option: '\(arg)'")
    } else {
      srcPaths.append(Path(arg))
    }
  }

  check(opt == nil, "dangling option flag: '\(opt!)'")

  for (key, val) in processEnvironment {
    if key == "PLOY_DBG_DEFS" {
      globalDbgDefSuffixes = Set(val.split(" "))
      errL("PLOY_DBG_DEFS: ", globalDbgDefSuffixes)
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

  let dumpPath = outPath.append(".dump.jsonl")
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

  let ctx = GlobalCtx(dumpPath: dumpPath, outFile: tmpFile, mapSend: mapSend)
  let rootSpace = setupRootSpace(ctx)

  let mainSpace = MainSpace(ctx, mainPath: mainPath, parent: rootSpace)
  rootSpace.bindings["MAIN"] = ScopeRecord(name: "MAIN", sym: nil, isLocal: false, kind: .space(mainSpace))

  mainSpace.add(defs: mainDefs, root: rootSpace)
  _ = mainSpace.getMainDef() // check that we have `main` before doing additional work.
  mainSpace.add(defs: libDefs, root: rootSpace)

  compileProgram(includePaths: incPaths, mainSpace: mainSpace, mapPath: mapPath)

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


func ploy_test_types(args:[String]) {
  fail("not implemented.")
}


func setupRootSpace(_ ctx: GlobalCtx) -> Space {
  let rootSpace = Space(ctx, pathNames: ["ROOT"], parent: nil)
  rootSpace.bindings["ROOT"] = ScopeRecord(name: "ROOT", sym: nil, isLocal: false, kind: .space(rootSpace))
  // NOTE: reference cycle; could fix it by making a special case for "ROOT" just before lookup failure.
  for t in intrinsicTypes {
    let rec = ScopeRecord(name: t.description, sym: nil, isLocal: false, kind: .type(t))
    rootSpace.bindings[t.description] = rec
  }
  return rootSpace
}


func nullGlobalCtx() -> GlobalCtx {
  return GlobalCtx(
    dumpPath: "/dev/null",
    outFile: try! File(path: "/dev/null", mode: .write),
    mapSend: FileHandle.nullDevice)
}

main()
