.import "ProfileModel.js" as Profile

function document(session) {
    var result = { schemaVersion: 1, bandSchema: Profile.BAND_SCHEMA, id: session.id, revision: session.revision, origin: "custom", name: session.name };
    Profile.SIDES.forEach(function (side) { if (session.included[side]) result[side] = Profile.copy(session.curves[side]); });
    return result;
}
function signature(session) {
    var value = document(session);
    value.name = Profile.normalizeName(value.name);
    return JSON.stringify(value);
}
function beginEdit(state, profile, library, generatedId) {
    if (profile) {
        var valid = Profile.validateProfile(profile, library);
        if (!valid.ok) throw new Error(valid.error);
        profile = valid.profile;
    }
    var custom = profile && profile.origin === "custom";
    var session = {
        baseline: Profile.copy(state), id: custom ? profile.id : Profile.newId(library, generatedId),
        revision: custom ? profile.revision + 1 : 1,
        name: profile ? (custom ? profile.name : Profile.copyName(profile.name, library)) : "",
        included: { input: !!(profile && profile.input), output: !!(profile && profile.output) },
        curves: { input: profile && profile.input ? Profile.copy(profile.input) : Profile.neutral(), output: profile && profile.output ? Profile.copy(profile.output) : Profile.neutral() },
        generation: 0, dirty: false
    };
    session.initial = signature(session);
    return session;
}
function previewState(session) {
    var next = Profile.copy(session.baseline);
    Profile.SIDES.forEach(function (side) {
        if (session.included[side]) next[side] = { eq: Profile.copy(session.curves[side]), source: null };
    });
    return next;
}
function previewEdit(session, change) {
    var next = Profile.copy(session);
    if (change.kind === "name" && typeof change.value === "string" && change.value.length <= 256) next.name = change.value;
    else if (Profile.SIDES.indexOf(change.side) !== -1 && change.kind === "include" && typeof change.value === "boolean") next.included[change.side] = change.value;
    else if (Profile.SIDES.indexOf(change.side) !== -1 && next.included[change.side]) next.curves[change.side] = Profile.changeEq(next.curves[change.side], change);
    else throw new Error("Include that side before editing its EQ.");
    next.generation++;
    next.dirty = signature(next) !== next.initial;
    return { session: next, state: previewState(next) };
}
function cancelEdit(session) { return Profile.copy(session.baseline); }
function saveIntent(session, library) { return Profile.validateProfile(document(session), library); }
