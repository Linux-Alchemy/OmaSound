const { test } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { load, plain, freeze } = require('../helpers/qml-js.cjs');
const P = load(path.join(__dirname, '../../models/ProfileModel.js'));
const E = load(path.join(__dirname, '../../models/EffectiveState.js'));
const D = load(path.join(__dirname, '../../models/EditSession.js'));
const F = load(path.join(__dirname, '../../models/FakeEngine.js'));
const C = load(path.join(__dirname, '../../models/ProfileController.js'));
const initial = () => C.initialState('test');
const action = (s, kind, more = {}) => C.transition(s, { kind, ...more });
const edit = (s, change) => action(s, 'draft', { change });
function newDraft() { let s = action(initial(), 'new'); s = edit(s, {kind:'name', value:'My profile'}); return edit(s, {kind:'include', side:'output', value:true}); }

 test('approved schema has ten fixed bands; boundaries accept finite values only', () => {
    assert.deepEqual(plain(P.FREQUENCIES), [31.25,62.5,125,250,500,1000,2000,4000,8000,16000]);
    for (const value of [-12, 12, 0.25]) { const eq=P.neutral();eq.gains[0]=value;assert.equal(P.validateEq(eq),true); }
    for (const value of [NaN,Infinity,-Infinity,12.01,-12.01,'3',null]) { const eq=P.neutral();eq.gains[0]=value;assert.equal(P.validateEq(eq),false); }
    const sparse=P.neutral();delete sparse.gains[0];assert.equal(P.validateEq(sparse),false);
    for (const gains of [[],Array(11).fill(0)]) assert.equal(P.validateEq({enabled:true,gains}),false);
 });
 test('strict profiles reject foreign state, unsupported versions and omitted sides', () => {
    const p=P.factoryFixtures()[0];
    for (const field of ['volume','mute','device','routing','__proto__']) {
        const v=plain(p);Object.defineProperty(v,field,{value:1,enumerable:true});assert.equal(P.validateProfile(v).ok,false);
    }
    for (const mutation of [v=>v.schemaVersion=2,v=>v.bandSchema='other',v=>v.input.volume=20,v=>v.input=null,v=>v.revision=0,v=>v.id='../oops',v=>{delete v.input;delete v.output;}]) {
        const v=plain(p);mutation(v);assert.equal(P.validateProfile(v).ok,false);
    }
 });
 test('names normalize, use code points, reject controls and case-insensitive collisions', () => {
    assert.equal(P.normalizeName('  Cafe\u0301  '),'Café');
    assert.equal(P.nameError('😀'.repeat(64),[],''),'');
    assert.notEqual(P.nameError('😀'.repeat(65),[],''),'');
    for (const n of ['', '   ', 'a\nb', 'a\u0085b']) assert.notEqual(P.nameError(n,[],''),'');
    assert.notEqual(P.nameError('CAFÉ',[{id:'custom-one',name:'Café'}],'custom-two'),'');
    assert.equal(P.nameError('CAFÉ',[{id:'custom-one',name:'Café'}],'custom-one'),'');
    assert.equal(P.nameError('<b>Music</b>',[],''),'');
 });
 test('included-side merging preserves the other side and never mutates inputs', () => {
    const [gaming,music]=P.factoryFixtures();const state=E.initialState();freeze(state);freeze(gaming);freeze(music);
    const both=E.applyProfile(state,gaming);freeze(both);
    const mixed=E.applyProfile(both,music);
    assert.deepEqual(plain(mixed.input),plain(both.input));assert.equal(mixed.output.source.name,'Fixture Music');
    assert.equal(state.input.source,null);assert.equal(gaming.output.gains[1],3);
    const input=plain(gaming);delete input.output;input.input.gains[2]=7;
    assert.deepEqual(plain(E.applyProfile(mixed,input).output),plain(mixed.output));
 });
 test('new editor has no included sides and no valid Save; first inclusion is neutral', () => {
    const s=action(initial(),'new');assert.equal(s.session.name,'');assert.equal(s.session.dirty,false);
    assert.deepEqual(plain(s.session.included),{input:false,output:false});assert.notEqual(C.saveError(s),'');
    const n=edit(s,{kind:'include',side:'input',value:true});assert.deepEqual(plain(C.shown(n).input.eq),plain(P.neutral()));
 });
 test('factory editing creates a unique custom copy and custom edits retain ID/revise', () => {
    let s=action(initial(),'edit',{id:'factory-fixture-gaming'});const original=plain(s.profiles[0]);
    assert.equal(s.session.name,'Fixture Gaming (copy)');assert.match(s.session.id,/^custom-/);
    s=action(s,'save');const saved=s.profiles.at(-1);assert.deepEqual(plain(s.profiles[0]),original);
    s=action(s,'edit',{id:saved.id});assert.equal(s.session.id,saved.id);assert.equal(s.session.revision,2);
    s=action(s,'save');assert.equal(s.profiles.length,3);assert.equal(s.profiles.at(-1).revision,2);
    s=action(s,'edit',{id:'factory-fixture-gaming'});assert.equal(s.session.name,'Fixture Gaming (copy 2)');
    assert.throws(()=>P.newId(s.profiles,saved.id));
 });
 test('unchecking restores baseline and rechecking retains the edited curve', () => {
    let s=action(initial(),'apply',{id:'factory-fixture-gaming'});const baseline=plain(s.committed);
    s=action(s,'new');s=edit(s,{kind:'include',side:'input',value:true});
    s=edit(s,{kind:'gain',side:'input',index:3,value:6});
    s=edit(s,{kind:'include',side:'input',value:false});assert.deepEqual(plain(C.shown(s).input),baseline.input);
    assert.equal(s.session.dirty,false);
    s=edit(s,{kind:'include',side:'input',value:true});assert.equal(C.shown(s).input.eq.gains[3],6);
 });
 test('dirty comparison clears when included values return to original', () => {
    let s=action(initial(),'edit',{id:'factory-fixture-music'});const before=s.session.curves.output.gains[0];
    s=edit(s,{kind:'gain',side:'output',index:0,value:8});assert.equal(s.session.dirty,true);
    s=edit(s,{kind:'gain',side:'output',index:0,value:before});assert.equal(s.session.dirty,false);
 });
 test('Save captures last draft; Cancel restores EQ without touching external device state', () => {
    let s=newDraft();const baseline=plain(s.committed);const devices={input:'mic1',output:'speaker',volume:20,muted:false};
    s=edit(s,{kind:'gain',side:'output',index:9,value:11.5});devices.output='headphones';devices.volume=45;devices.muted=true;
    const saved=action(s,'save');assert.equal(saved.profiles.at(-1).output.gains[9],11.5);
    const cancelled=action(s,'cancel');assert.deepEqual(plain(cancelled.committed),baseline);
    assert.deepEqual(devices,{input:'mic1',output:'headphones',volume:45,muted:true});
 });
 test('bypass/Flat preserve appropriate fields and do not rewrite named profiles', () => {
    let s=action(initial(),'apply',{id:'factory-fixture-gaming'});const profiles=plain(s.profiles);
    s=action(s,'eq',{side:'output',change:{kind:'enabled',value:false}});assert.equal(s.committed.output.eq.gains[1],3);
    s=action(s,'eq',{side:'output',change:{kind:'flat'}});assert.equal(s.committed.output.eq.enabled,false);
    assert.equal(s.committed.output.eq.gains.every(v=>v===0),true);assert.equal(s.committed.output.source,null);
    assert.equal(s.committed.input.source.name,'Fixture Gaming');assert.deepEqual(plain(s.profiles),profiles);
 });
 test('dirty navigation waits; Keep editing leaves draft, Discard applies target', () => {
    let s=newDraft();s=action(s,'apply',{id:'factory-fixture-gaming'});assert.equal(s.pendingAction.kind,'apply');
    const session=plain(s.session);s=action(s,'resolve',{choice:'keep'});assert.deepEqual(plain(s.session),session);
    s=action(s,'apply',{id:'factory-fixture-music'});s=action(s,'resolve',{choice:'discard'});
    assert.equal(s.session,null);assert.equal(s.committed.output.source.name,'Fixture Music');assert.equal(s.committed.input.source,null);
 });
 test('failed Save retains pending close and draft; successful retry closes', () => {
    let s=newDraft();s.failSave=true;s=action(s,'close');const draft=plain(s.session);
    s=action(s,'resolve',{choice:'save'});assert.match(s.error,/Save failure/);assert.equal(s.closeRequested,false);
    assert.deepEqual(plain(s.session),draft);assert.equal(s.profiles.length,2);assert.equal(s.pendingAction.kind,'close');
    s=action(s,'resolve',{choice:'save'});assert.equal(s.closeRequested,true);assert.equal(s.profiles.length,3);
 });
 test('clean editor departure restores preview before close', () => {
    let s=initial();const baseline=plain(s.committed);s=action(s,'edit',{id:'factory-fixture-gaming'});
    assert.equal(s.session.dirty,false);assert.equal(C.shown(s).input.eq.gains[4],2);
    s=action(s,'close');assert.equal(s.closeRequested,true);assert.deepEqual(plain(s.committed),baseline);
    assert.equal(s.engine.sides.input.observed.gains[4],0);
 });
 test('delayed preview cannot overwrite Cancel or a newer slider generation', () => {
    let s=newDraft();s.defer=true;s=edit(s,{kind:'gain',side:'output',index:0,value:8});const old=s.engine.generation;
    s=edit(s,{kind:'gain',side:'output',index:0,value:9});const newer=plain(s.engine);
    assert.deepEqual(plain(F.acknowledge(s.engine,old,{output:{status:'applied'}})),newer);
    s=action(s,'cancel');s.engine=F.settle(s.engine,s.available,'',false);const restored=plain(s.engine);
    assert.deepEqual(plain(F.acknowledge(s.engine,old,{output:{status:'applied'}})),restored);
    assert.equal(s.engine.sides.output.observed.gains[0],0);
 });
 test('partial failure reports confirmed restoration and uncertain restoration separately', () => {
    const before=E.initialState(), after=E.applyProfile(before,P.factoryFixtures()[0]);const pending=F.request(F.create(before),after);
    const failed=F.acknowledge(pending,pending.generation,{input:{status:'applied',restored:true},output:{status:'failed',restored:false}});
    assert.equal(failed.sides.input.status,'failed-restored');assert.deepEqual(plain(failed.sides.input.observed),plain(before.input.eq));
    assert.equal(failed.sides.output.status,'uncertain');assert.equal(failed.sides.output.observed,null);
    assert.equal(failed.sides.output.desired.gains[1],3);
 });
 test('missing device retains requested EQ and permits truthful in-memory Save', () => {
    let s=newDraft();s=action(s,'available',{side:'output',value:false});s=edit(s,{kind:'gain',side:'output',index:3,value:4});s=action(s,'save');
    assert.equal(s.profiles.at(-1).output.gains[3],4);assert.equal(s.engine.sides.output.status,'waiting');assert.equal(s.engine.sides.output.observed,null);
    s=action(s,'available',{side:'output',value:true});assert.equal(s.engine.sides.output.status,'simulated');assert.equal(s.engine.sides.output.observed.gains[3],4);
 });
 test('pure transitions accept frozen inputs and invalid changes preserve model', () => {
    const s=newDraft();freeze(s);const before=plain(s);const bad=edit(s,{kind:'gain',side:'output',index:20,value:3});
    assert.notEqual(bad.error,'');assert.deepEqual(plain(s),before);assert.deepEqual(plain(bad.session),before.session);
 });

const S = load(path.join(__dirname, '../../models/PersistentState.js'));
test('stored snapshot omits physical state and drafts; restore preserves independent origins', () => {
    let state=action(initial(),'apply',{id:'factory-fixture-gaming'});
    state=action(state,'apply',{id:'factory-fixture-music'});
    const committed=plain(state.committed);
    state=action(state,'new');state=edit(state,{kind:'include',side:'input',value:true});
    state=edit(state,{kind:'gain',side:'input',index:0,value:10});
    freeze(state);
    const stored=S.value(state);freeze(stored);
    assert.deepEqual(Object.keys(stored).sort(),['effective','profiles']);
    assert.deepEqual(plain(stored.effective),committed);
    const restored=S.restore(initial(),stored);
    assert.equal(restored.committed.input.source.name,'Fixture Gaming');
    assert.equal(restored.committed.output.source.name,'Fixture Music');
    assert.equal(restored.session,null);
});
test('storage validation rejects unsupported state, duplicate identities and excessive libraries', () => {
    const valid=S.value(action(newDraft(),'save'));
    assert.doesNotThrow(()=>S.validate(valid));
    for (const change of [v=>v.volume=4,v=>v.profiles.push(plain(v.profiles[0])),v=>v.profiles=Array(257).fill(v.profiles[0]),v=>v.effective.input.source={id:'custom-missing',revision:1,name:'Missing'}]) {
        const broken=plain(valid);change(broken);assert.throws(()=>S.validate(broken));
    }
    assert.notEqual(P.nameError('\ud800',[],''),'');
});
test('explicit storage reload rebases a retained draft without replacing its curve or pending close', () => {
    let old=action(newDraft(),'save');const id=old.profiles.at(-1).id;
    let draft=action(old,'edit',{id});draft=edit(draft,{kind:'gain',side:'output',index:0,value:6});draft=action(draft,'close');
    let newer=plain(old);newer.profiles.at(-1).revision=5;newer.committed.input.eq.gains[0]=4;
    const restored=S.restore(draft,S.value(newer));
    assert.equal(restored.session.revision,6);assert.equal(restored.session.curves.output.gains[0],6);
    assert.equal(restored.session.baseline.input.eq.gains[0],4);assert.equal(restored.pendingAction.kind,'close');
    const saved=action(restored,'resolve',{choice:'save'});
    assert.equal(saved.committed.input.eq.gains[0],4);assert.equal(saved.closeRequested,true);
});
