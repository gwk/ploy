// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

function _tramp(p) {
  while (p.c !== undefined) {
    p = p.c(p.v)
  }
  return p.v
}

function _raise(msg) {
  throw msg
}

// in FS.
let FS__write_Bool  = function($) { HOST__fs.writeSync($.file, $.bool); return {}; }
let FS__write_Int   = function($) { HOST__fs.writeSync($.file, $.int);  return {}; }
let FS__write_Str   = function($) { HOST__fs.writeSync($.file, $.str);  return {}; }

// GLOBAL.
function eq_Int($) { return { v: $["0"] === $["1"] }; }


// in HOST.
let HOST__fs = require('fs');
let HOST__process = process

// in PROC.
let PROC__exit = function($) { HOST__process.exit($); return {}; }
let PROC__std_out = HOST__process.stdout.fd
let PROC__std_err = HOST__process.stderr.fd

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
//const PROC__cmd   = HOST__process.argv
//const PROC__args  = HOST__process.argv.slice(1)
