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
const game_ref = sysjs.addValue(Game);

// Write global persistant memory into the module.
const import_memory_address = instance.exports.persistantMemoryAddress();
const import_memory_length = instance.exports.persistantMemoryLength();

RawMemory.setActiveSegments([0]);

var module_memory = new Uint8Array(instance.exports.memory.buffer, import_memory_address, import_memory_length);
var screeps_memory = new Uint8Array(new TextEncoder().encode(RawMemory.segments[0]), 0, import_memory_length);
module_memory.set(screeps_memory, 0);

// Main loop.
module.exports.loop = function () {

    // Run module.
    instance.exports.run(game_ref);

    // Overwrite global persistant memory with the module's memory.
    module_memory = new Uint8Array(instance.exports.memory.buffer, import_memory_address, import_memory_length);
    RawMemory.segments[0] = new TextDecoder().decode(module_memory);

}
