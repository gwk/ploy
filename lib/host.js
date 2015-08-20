// Dedicated to the public domain under CC0: https://creativecommons.org/publicdomain/zero/1.0/.

const HOST__fs = require('fs');
const HOST__process = process

// TODO: these are probably the wrong type;
// need to repackaged into proper ploy types or hidden behind accessor functions.
const HOST__cmd   = HOST__process.argv
const HOST__args  = HOST__process.argv.slice(1)

const HOST__std_out = HOST__process.stdout.fd
const HOST__std_err = HOST__process.stderr.fd

const PROC__exit = function($) { HOST__process.exit($) }

//const write_Str = function($) { _host__fs.writeSync($.file, $.str) }
//const write_Int = function($) { _host__fs.writeSync($.file, $.str) }
//const write_Bool = function($) { _host__fs.writeSync($.file, $.bool) }
