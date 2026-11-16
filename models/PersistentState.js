.import "ProfileModel.js" as Profile
.import "ProfileController.js" as Controller
.import "FakeEngine.js" as Engine

var MAX_PROFILES = 256;
function value(state) {
    return { profiles: Profile.copy(state.profiles.filter(function (p) { return p.origin === "custom"; })), effective: Profile.copy(state.committed) };
}
function validate(value) {
    if (!Profile.keys(value, ["profiles", "effective"]) || !Array.isArray(value.profiles) || value.profiles.length > MAX_PROFILES
        || !Profile.keys(value.effective, Profile.SIDES)) throw new Error("Invalid stored state.");
    var library = Profile.factoryFixtures();
    value.profiles.forEach(function (p) {
        var valid = Profile.validateProfile(p, library);
        if (!valid.ok || p.origin !== "custom" || library.some(function (known) { return known.id === p.id; })) throw new Error("Invalid stored profile.");
        library.push(valid.profile);
    });
    Profile.SIDES.forEach(function (side) {
        var row = value.effective[side];
        if (!Profile.keys(row, ["eq", "source"]) || !Profile.validateEq(row.eq)) throw new Error("Invalid stored EQ.");
        if (row.source !== null) {
            var source = row.source;
            if (!Profile.keys(source, ["id", "revision", "name"]) || !Number.isSafeInteger(source.revision) || source.revision < 1
                || Profile.nameError(source.name, [], "") || !library.some(function (p) { return p.id === source.id; })) throw new Error("Invalid stored provenance.");
        }
    });
    return library;
}
function restore(current, stored) {
    var next = Profile.copy(current);
    next.profiles = validate(stored);
    next.committed = Profile.copy(stored.effective);
    // Explicit conflict reload preserves the draft, now against the newest baseline.
    if (next.session) {
        next.session.baseline = Profile.copy(next.committed);
        var existing = next.profiles.find(function (p) { return p.id === next.session.id; });
        if (existing) next.session.revision = existing.revision + 1;
    }
    next.engine = Engine.settle(Engine.request(next.engine, Controller.shown(next)), next.available, "", false);
    next.error = "";
    next.message = "Loaded saved fixture profiles and EQ.";
    return next;
}
function differs(a, b) { return JSON.stringify(value(a)) !== JSON.stringify(value(b)); }
