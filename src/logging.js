// Functions for writing to the console.

class Logger {
    constructor() {
        this._memory = 0
    }

    set_memory(memory) {
        this._memory = memory;
    }

    decode_string(pointer, length) {
        const slice = new Uint8Array(
            this._memory.buffer,
            pointer,
            length
        );
        return new TextDecoder().decode(slice);
    }

    log(str, len) {
        console.log(this.decode_string(str, len));
    }
};

module.exports = { Logger };
