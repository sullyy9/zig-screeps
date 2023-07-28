var logging = require('logging')
var logger = new logging.Logger();


// Load the WASM module.
const bytecode = require('zig-screeps');
const wasm_module = new WebAssembly.Module(bytecode);

// Define imports into WASM module.
const imports = {
    env: {
        memoryBase: 0,
        tableBase: 0,
        memory: new WebAssembly.Memory({ initial: 256 }),
        table: new WebAssembly.Table({ initial: 0, element: 'anyfunc' }),
    },
    logging: {
        log: function (str, len) { logger.log(str, len) },
    },
    screeps: {

    },

};

// Create WASM module instance.
const instance = new WebAssembly.Instance(wasm_module, imports);
const exports = instance.exports

// Initialise logger.
logger.set_memory(exports.memory)

// Main loop.
module.exports.loop = function () {
    instance.exports.run();
}
