const sysjs = require('heap').sysjs;

// Load the WASM module.
const bytecode = require('screeps-ai');
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

// Write global persistant memory into the module.
const import_memory_address = instance.exports.persistantMemoryAddress();
const import_memory_length = instance.exports.persistantMemoryLength();

RawMemory.setActiveSegments([0]);

var module_memory = new Uint8Array(instance.exports.memory.buffer, import_memory_address, import_memory_length);

if (RawMemory.segments[0] != undefined) {
    let screeps_memory = Uint8Array.from(RawMemory.segments[0], (char) => char.codePointAt(0))

    // The persistant memory may sometimes not be ready so don't pass it in if thats the case.
    if (module_memory.length != screeps_memory.length) {
        console.log("Length mismatch between module and screeps memory:")
        console.log("Module memory:  ", module_memory.length)
        console.log("Screeps memory: ", screeps_memory.length)
        console.log()
    } else {
        module_memory.set(screeps_memory, 0);
    }
}

// Main loop.
module.exports.loop = function () {

    // Run module.
    const game_ref = sysjs.addValue(Game);
    instance.exports.run(game_ref);

    // Overwrite global persistant memory with the module's memory.
    module_memory = new Uint8Array(instance.exports.memory.buffer, import_memory_address, import_memory_length);
    RawMemory.segments[0] = new TextDecoder("iso-8859-1").decode(module_memory);
}
