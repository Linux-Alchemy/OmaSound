// Run the same pure QML JavaScript modules in Node without a second implementation.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
function load(file, cache = new Map()) {
    file = path.resolve(file);
    if (cache.has(file)) return cache.get(file);
    const context = vm.createContext({});
    cache.set(file, context);
    const source = fs.readFileSync(file, 'utf8').replace(/^\.import "([^"]+)" as (\w+)\s*$/gm, (_, relative, name) => {
        context[name] = load(path.join(path.dirname(file), relative), cache);
        return '';
    });
    vm.runInContext(source, context, { filename: file });
    return context;
}
function plain(value) { return JSON.parse(JSON.stringify(value)); }
function freeze(value) { Object.freeze(value); Object.values(value).forEach(v => { if (v && typeof v === 'object' && !Object.isFrozen(v)) freeze(v); }); return value; }
module.exports = { load, plain, freeze };
