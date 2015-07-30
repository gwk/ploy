// Copyright © 2015 gwk. Permission to use this file is granted in ploy/license.txt.

import Darwin


func stringForCurrentError() -> String {
  return String.fromCString(strerror(errno))!
}


class File: CustomStringConvertible {
  typealias Descriptor = Int32
  
  let fd: Descriptor
  let desc: String
  
  deinit {
    close(fd)
  }
  
  required init(fd: Descriptor, desc: String) {
    self.fd = fd
    self.desc = desc
  }
  
  init(path: String, mode: CInt, create: mode_t? = nil) {
    self.desc = path
    if let permissions = create {
      fd = open(path, mode | O_CREAT, permissions)
    } else {
      fd = open(path, mode)
    }
    check(fd >= 0, "open failed for path: '\(path)'; error: \(stringForCurrentError()).")
  }
  
  var description: String {
    return "\(self.dynamicType)(fd:\(fd), desc:'\(desc)')"
  }
  
  var stats: stat {
    var stat_res = stat()
    let res = fstat(fd, &stat_res)
    check(res == 0, "File stat failed: '\(desc)'.")
    return stat_res
  }
}


class InFile: File {
  
  required init(fd: Descriptor, desc: String) { super.init(fd: fd, desc: desc) }
  
  override init(path: String, mode: CInt, create: mode_t? = nil) {
    fatalError("ReadFile should use init(path, create?)")
  }
  
  init(path: String, create: mode_t? = nil) {
    super.init(path: path, mode: O_RDONLY, create: create)
  }
  
  var len: Int { return Int(stats.st_size) }
  
  func read(offset offset: Int, len: Int, ptr: UnsafeMutablePointer<Void>) -> Int {
    let len_act = Darwin.pread(Int32(fd), ptr, len, off_t(offset))
    check(len_act >= 0, "file read failed: '\(desc)'.")
    return len_act
  }
  
  func read() -> String {
    let len = self.len
    let buffer = malloc(len)
    check(buffer != nil, "File.read: malloc failed for size: \(len); '\(desc)'.")
    let len_act = read(offset: 0, len: len, ptr: buffer)
    check(len_act == len, "File.read: expected read length: \(len); actually read \(len_act).")
    let (s, _) = String.fromCStringRepairingIllFormedUTF8(unsafeBitCast(buffer, UnsafePointer<CChar>.self))
    free(buffer)
    check(s != nil, "File.read: UTF8 error could not be repaired: '\(desc)'.")
    return s!
  }
  
  func copyTo(outFile: OutFile) {
    let attrs: Int32 = COPYFILE_ACL|COPYFILE_STAT|COPYFILE_XATTR|COPYFILE_DATA
    let res = fcopyfile(self.fd, outFile.fd, copyfile_state_t(), copyfile_flags_t(attrs))
    check(res == 0, "File.copyTo: failed to copy from \(self) to \(outFile)")
  }
}


class OutFile: File, OutputStreamType {
  
  required init(fd: Descriptor, desc: String) { super.init(fd: fd, desc: desc) }

  override init(path: String, mode: CInt, create: mode_t? = nil) {
    fatalError("OutFile should use init(path, create?).")
  }
  
  init(path: String, create: mode_t? = nil) {
    super.init(path: path, mode: O_WRONLY, create: create)
  }
  
  func write(string: String) {
    string.nulTerminatedUTF8.withUnsafeBufferPointer {
      (buffer: UnsafeBufferPointer<UTF8.CodeUnit>) -> () in
        Darwin.write(fd, buffer.baseAddress, buffer.count)
    }
  }
}


func copy(fromPath fromPath: String, toPath: String, create: mode_t? = nil) {
  InFile(path: fromPath).copyTo(OutFile(path: toPath, create: create))
}


var std_in = InFile(fd: STDIN_FILENO, desc: "std_in")
var std_out = OutFile(fd: STDOUT_FILENO, desc: "std_out")
var std_err = OutFile(fd: STDERR_FILENO, desc: "std_err")


func out<T>(item: T) { print(item,  &std_out, appendNewline: false) }
func outL<T>(item: T) { print(item, &std_out, appendNewline: true) }

func err<T>(item: T) { print(item, &std_err, appendNewline: false) }
func errL<T>(item: T) { print(item, &std_err, appendNewline: true) }


