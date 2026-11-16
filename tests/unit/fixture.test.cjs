const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../../models/Fixture.js'), 'utf8'), model);

test('open accepts only bounded empty objects, never settings or executable input', () => {
    for (const value of ['', '{}', ' { } ']) assert.equal(model.acceptsPayload(value), true);
    for (const value of [null, 1, [], '[]', 'null', '{"mode":"live"}', '{', ' '.repeat(1025), '{"__proto__":{}}', 'é'])
        assert.equal(model.acceptsPayload(value), false, String(value));
});

test('fixture state is independent between instances and sides', () => {
    const original = model.initialState();
    const next = model.change(original, 'output', 'volume', 15, 0);
    assert.equal(original.output.volume, 40);
    assert.equal(next.output.volume, 15);
    assert.equal(next.input.volume, 60);
    assert.equal(model.initialState().output.volume, 40);
});

test('bypass preserves fixture curve, flat preserves volume, mute and device', () => {
    let state = model.initialState();
    state = model.change(state, 'input', 'device', 0, 0);
    state = model.change(state, 'input', 'mute', 0, 0);
    state = model.change(state, 'input', 'band', 0.75, 3);
    state = model.change(state, 'input', 'enabled', 0, 0);
    state = model.change(state, 'input', 'enabled', 0, 0);
    assert.equal(state.input.bands[3], 0.75);
    state = model.change(state, 'input', 'flat', 0, 0);
    assert.equal(state.input.bands.every(v => v === 0), true);
    assert.equal(state.input.volume, 60);
    assert.equal(state.input.muted, true);
    assert.equal(state.input.device, 1);
});

test('invalid fixture controls fail without mutating state', () => {
    const state = model.initialState();
    const before = JSON.stringify(state);
    for (const args of [['input', 'volume', NaN, 0], ['input', 'volume', Infinity, 0], ['output', 'volume', 101, 0], ['input', 'band', 0, 10], ['input', 'band', 0, 0.5], ['input', 'band', -2, 0], ['wrong', 'mute', 0, 0], ['input', 'live', 0, 0]])
        assert.throws(() => model.change(state, ...args));
    assert.equal(JSON.stringify(state), before);
});
