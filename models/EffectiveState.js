.import "ProfileModel.js" as Profile

function initialState() {
    return { input: { eq: Profile.neutral(), source: null }, output: { eq: Profile.neutral(), source: null } };
}
function applyProfile(state, profile) {
    var valid = Profile.validateProfile(profile);
    if (!valid.ok) throw new Error(valid.error);
    var next = Profile.copy(state);
    Profile.SIDES.forEach(function (side) {
        if (Object.prototype.hasOwnProperty.call(valid.profile, side)) next[side] = {
            eq: Profile.copy(valid.profile[side]),
            source: { id: profile.id, revision: profile.revision, name: valid.profile.name }
        };
    });
    return next;
}
function change(state, side, edit) {
    if (Profile.SIDES.indexOf(side) === -1) throw new Error("Unknown EQ side.");
    var next = Profile.copy(state);
    next[side] = { eq: Profile.changeEq(state[side].eq, edit), source: null };
    return next;
}
function label(state, side) { return state[side].source ? state[side].source.name : "Custom / neutral"; }
