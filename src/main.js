const sysjs = require('mach-sysjs').sysjs;

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
    sysjs: { ...sysjs },
};

// Create WASM module instance.
const instance = new WebAssembly.Instance(wasm_module, imports);

// Initialise bindings. The global object won't exist so add any required global objects manually
// and pass their references into the main function.
sysjs.init(instance);
let game_ref = sysjs.addValue(Game);

// Main loop.
module.exports.loop = function () {
    instance.exports.run(game_ref);
}
