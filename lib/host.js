// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

// in FS.
const FS__write_Bool  = function($) { HOST__fs.writeSync($.file, $.bool) }
const FS__write_Int   = function($) { HOST__fs.writeSync($.file, $.int) }
const FS__write_Str   = function($) { HOST__fs.writeSync($.file, $.str) }

// in HOST.
const HOST__fs = require('fs');
const HOST__process = process

// in PROC.
const PROC__exit = function($) { HOST__process.exit($) }
const PROC__std_out = HOST__process.stdout.fd
const PROC__std_err = HOST__process.stderr.fd

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
//const PROC__cmd   = HOST__process.argv
//const PROC__args  = HOST__process.argv.slice(1)


