.import "ProfileModel.js" as Profile

// Pure simulated observation. This is not a live backend protocol.
function create(effective) {
    var sides = {};
    Profile.SIDES.forEach(function (side) { sides[side] = { desired: Profile.copy(effective[side].eq), observed: Profile.copy(effective[side].eq), status: "simulated" }; });
    return { generation: 0, sides: sides, pending: null };
}
function request(engine, effective, forceSides) {
    var next = Profile.copy(engine);
    var changes = {};
    Profile.SIDES.forEach(function (side) {
        if ((forceSides || []).indexOf(side) !== -1 || JSON.stringify(effective[side].eq) !== JSON.stringify(engine.sides[side].desired)) changes[side] = Profile.copy(effective[side].eq);
    });
    // Carry superseded pending sides forward; never strand an old pending flag.
    if (engine.pending) Object.keys(engine.pending.changes).forEach(function (side) { changes[side] = Profile.copy(effective[side].eq); });
    next.generation++;
    next.pending = { generation: next.generation, changes: changes, before: Profile.copy(engine.sides) };
    Object.keys(changes).forEach(function (side) { next.sides[side].desired = Profile.copy(changes[side]); next.sides[side].status = "pending"; });
    return next;
}
function acknowledge(engine, generation, results) {
    if (!engine.pending || generation !== engine.generation || generation !== engine.pending.generation) return Profile.copy(engine);
    var next = Profile.copy(engine);
    var sides = Object.keys(engine.pending.changes);
    var failed = sides.some(function (side) { return !results[side] || ["applied", "waiting"].indexOf(results[side].status) === -1; });
    sides.forEach(function (side) {
        var result = results[side] || { status: "unknown", restored: false };
        var prior = engine.pending.before[side];
        if (failed) {
            // The fake result explicitly reports restoration; no implied atomicity.
            if (result.restored === true && prior.observed !== null) {
                next.sides[side].observed = Profile.copy(prior.observed);
                next.sides[side].status = "failed-restored";
            } else {
                next.sides[side].observed = null;
                next.sides[side].status = "uncertain";
            }
        } else if (result.status === "waiting") {
            next.sides[side].observed = null;
            next.sides[side].status = "waiting";
        } else {
            next.sides[side].observed = Profile.copy(engine.pending.changes[side]);
            next.sides[side].status = "simulated";
        }
    });
    next.pending = null;
    return next;
}
function settle(engine, available, failSide, failRestore) {
    if (!engine.pending) return Profile.copy(engine);
    var results = {};
    Object.keys(engine.pending.changes).forEach(function (side) {
        results[side] = { status: side === failSide ? "failed" : (available[side] ? "applied" : "waiting"), restored: available[side] && !failRestore };
    });
    return acknowledge(engine, engine.generation, results);
}
