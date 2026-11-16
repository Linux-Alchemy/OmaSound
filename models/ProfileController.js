.import "ProfileModel.js" as Profile
.import "EffectiveState.js" as Effective
.import "EditSession.js" as Edit
.import "FakeEngine.js" as Engine

function initialState(seed) {
    var effective = Effective.initialState();
    return { profiles: Profile.factoryFixtures(), committed: effective, session: null, engine: Engine.create(effective),
        pendingAction: null, closeRequested: false, serial: 0, seed: seed, message: "Profiles are saved in memory only.", error: "",
        available: { input: true, output: true }, defer: false, failSide: "", failRestore: false, failSave: false };
}
function shown(state) { return state.session ? Edit.previewState(state.session) : state.committed; }
function find(state, id) {
    var p = state.profiles.find(function (profile) { return profile.id === id; });
    if (!p) throw new Error("Profile no longer exists.");
    return p;
}
function sync(state, forceSides) {
    state.engine = Engine.request(state.engine, shown(state), forceSides);
    if (!state.defer) {
        state.engine = Engine.settle(state.engine, state.available, state.failSide, state.failRestore);
        state.failSide = "";
        state.failRestore = false;
    }
}
function cancel(state) {
    if (!state.session) return;
    state.committed = Edit.cancelEdit(state.session);
    state.session = null;
    sync(state);
}
function perform(state, action) {
    if (action.kind === "close") { state.closeRequested = true; return; }
    if (action.kind === "apply") {
        state.committed = Effective.applyProfile(state.committed, find(state, action.id));
        sync(state);
        state.message = "Profile selected in memory; application status is shown per side.";
        return;
    }
    if (action.kind === "new" || action.kind === "edit") {
        var profile = action.kind === "edit" ? find(state, action.id) : null;
        state.serial++;
        state.session = Edit.beginEdit(state.committed, profile, state.profiles, "custom-" + state.seed + "-" + state.serial);
        sync(state);
        return;
    }
    throw new Error("Unknown navigation action.");
}
function save(state) {
    if (!state.session) throw new Error("No profile editor is open.");
    var valid = Edit.saveIntent(state.session, state.profiles);
    if (!valid.ok) { state.error = valid.error; return false; }
    if (state.failSave) { state.failSave = false; state.error = "Simulated Save failure. Draft retained; nothing saved."; return false; }
    var profile = valid.profile;
    var index = state.profiles.findIndex(function (p) { return p.id === profile.id; });
    if (index !== -1 && state.profiles[index].origin !== "custom") throw new Error("Factory profiles cannot be overwritten.");
    var committed = Effective.applyProfile(state.session.baseline, profile);
    if (index === -1) state.profiles.push(profile);
    else state.profiles[index] = profile;
    state.committed = committed;
    state.session = null;
    sync(state);
    state.message = "Saved in memory only. Preview stop will discard this library.";
    return true;
}
function transition(current, action) {
    var next = Profile.copy(current);
    next.error = "";
    next.closeRequested = false;
    try {
        if (action.kind === "resolve") {
            if (!next.pendingAction) return next;
            var pending = next.pendingAction;
            if (action.choice === "keep") { next.pendingAction = null; return next; }
            if (action.choice === "save") { if (!save(next)) return next; }
            else if (action.choice === "discard") cancel(next);
            else throw new Error("Unknown unsaved-change choice.");
            next.pendingAction = null;
            perform(next, pending);
        } else if (next.pendingAction) {
            next.error = "Resolve the unsaved changes first.";
        } else if (["new", "edit", "apply", "close"].indexOf(action.kind) !== -1) {
            if (next.session && next.session.dirty) next.pendingAction = Profile.copy(action);
            else { cancel(next); perform(next, action); }
        } else if (action.kind === "draft") {
            if (!next.session) throw new Error("No profile editor is open.");
            next.session = Edit.previewEdit(next.session, action.change).session;
            sync(next);
        } else if (action.kind === "cancel") {
            cancel(next);
            next.message = "Draft discarded; previous EQ restored where confirmed.";
        } else if (action.kind === "save") save(next);
        else if (action.kind === "eq") {
            if (next.session) {
                var edit = Profile.copy(action.change);
                edit.side = action.side;
                next.session = Edit.previewEdit(next.session, edit).session;
            } else next.committed = Effective.change(next.committed, action.side, action.change);
            sync(next);
        } else if (action.kind === "available" && Profile.SIDES.indexOf(action.side) !== -1 && typeof action.value === "boolean") {
            next.available[action.side] = action.value;
            sync(next, [action.side]);
        } else throw new Error("Unknown model action.");
        return next;
    } catch (error) {
        var failed = Profile.copy(current);
        failed.error = String(error.message || error);
        failed.closeRequested = false;
        return failed;
    }
}
function saveError(state) { return state.session ? Edit.saveIntent(state.session, state.profiles).error || "" : "No editor is open."; }
function sideLabel(state, side) {
    if (state.session && state.session.included[side]) return "Preview: " + (Profile.normalizeName(state.session.name) || "new profile");
    return Effective.label(shown(state), side);
}
