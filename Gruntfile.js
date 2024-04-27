module.exports = function (grunt) {

    grunt.loadNpmTasks('grunt-screeps');

    grunt.initConfig({
        screeps: {
            options: {
                email: 'ryansully96@googlemail.com',
                token: '487dd1b8-7fa4-4e63-93a4-3d6c020b8a83',
                branch: 'default',
                //server: 'season'
            },
            dist: {
                src: ['./zig-out/bin/main.js', './zig-out/bin/heap.js', './zig-out/bin/screeps-ai.wasm']
            }
        }
    });
}