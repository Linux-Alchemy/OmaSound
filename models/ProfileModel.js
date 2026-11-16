// Versioned EQ-only contract accepted in ADR 0002. No I/O.
var FREQUENCIES = [31.25, 62.5, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
var BAND_SCHEMA = "ten-band-v1";
var MIN_GAIN = -12;
var MAX_GAIN = 12;
var STEP = 0.5;
var SIDES = ["input", "output"];

function copy(value) { return JSON.parse(JSON.stringify(value)); }
function object(value) { return value !== null && typeof value === "object" && !Array.isArray(value); }
function keys(value, allowed) {
    return object(value) && Object.keys(value).every(function (key) { return allowed.indexOf(key) !== -1; });
}
function neutral() { return { enabled: false, gains: FREQUENCIES.map(function () { return 0; }) }; }
function validateEq(eq) {
    return keys(eq, ["enabled", "gains"]) && typeof eq.enabled === "boolean" && Array.isArray(eq.gains)
        && eq.gains.length === 10 && Array.from(eq.gains).every(function (v) { return typeof v === "number" && Number.isFinite(v) && v >= MIN_GAIN && v <= MAX_GAIN; });
}
function normalizeName(value) { return typeof value === "string" ? value.trim().normalize("NFC") : ""; }
function nameError(value, library, ownId) {
    if (typeof value !== "string" || value.length > 256 || /[\u0000-\u001f\u007f-\u009f]/.test(value)) return "Use a name without control characters.";
    var name = normalizeName(value);
    if (Array.from(name).some(function (c) { var n = c.codePointAt(0); return n >= 0xd800 && n <= 0xdfff; })) return "Use a valid Unicode name.";
    if (!name || Array.from(name).length > 64) return "Use a name from 1 to 64 characters.";
    if ((library || []).some(function (p) { return p.id !== ownId && normalizeName(p.name).toLowerCase() === name.toLowerCase(); })) return "That profile name is already in use.";
    return "";
}
function validateProfile(value, library) {
    if (!keys(value, ["schemaVersion", "bandSchema", "id", "revision", "origin", "name", "input", "output"])) return { ok: false, error: "Profile contains unsupported fields." };
    if (value.schemaVersion !== 1 || value.bandSchema !== BAND_SCHEMA) return { ok: false, error: "Unsupported profile or band schema." };
    if (typeof value.id !== "string" || !/^(custom|factory)-[a-zA-Z0-9-]{1,72}$/.test(value.id)
        || !Number.isSafeInteger(value.revision) || value.revision < 1
        || ["factory", "custom"].indexOf(value.origin) === -1 || value.id.indexOf(value.origin + "-") !== 0) return { ok: false, error: "Invalid profile identity." };
    var error = nameError(value.name, library, value.id);
    if (error) return { ok: false, error: error };
    if (!Object.prototype.hasOwnProperty.call(value, "input") && !Object.prototype.hasOwnProperty.call(value, "output")) return { ok: false, error: "Include input, output, or both." };
    for (var i = 0; i < SIDES.length; i++) {
        var side = SIDES[i];
        if (Object.prototype.hasOwnProperty.call(value, side) && !validateEq(value[side])) return { ok: false, error: "Invalid " + side + " EQ settings." };
    }
    var profile = copy(value);
    profile.name = normalizeName(value.name);
    return { ok: true, profile: profile };
}
function changeEq(eq, change) {
    if (!validateEq(eq)) throw new Error("Invalid EQ state.");
    var next = copy(eq);
    if (change.kind === "enabled" && typeof change.value === "boolean") next.enabled = change.value;
    else if (change.kind === "flat") next.gains = next.gains.map(function () { return 0; });
    else if (change.kind === "gain" && Number.isInteger(change.index) && change.index >= 0 && change.index < 10
        && typeof change.value === "number" && Number.isFinite(change.value) && change.value >= MIN_GAIN && change.value <= MAX_GAIN) next.gains[change.index] = change.value;
    else throw new Error("Invalid EQ change.");
    return next;
}
function newId(library, candidate) {
    if (typeof candidate !== "string" || !/^custom-[a-zA-Z0-9-]{1,72}$/.test(candidate) || library.some(function (p) { return p.id === candidate; })) throw new Error("Profile ID collision or invalid ID.");
    return candidate;
}
function copyName(name, library) {
    var base = Array.from(normalizeName(name)).slice(0, 48).join("");
    for (var i = 1; i <= library.length + 1; i++) {
        var result = base + " (copy" + (i === 1 ? "" : " " + i) + ")";
        if (!nameError(result, library, "")) return result;
    }
    throw new Error("Could not create a unique copy name.");
}
function factoryFixtures() {
    // Synthetic contrasting curves for merge verification, not release presets.
    var a = { schemaVersion: 1, bandSchema: BAND_SCHEMA, id: "factory-fixture-gaming", revision: 1, origin: "factory", name: "Fixture Gaming", input: neutral(), output: neutral() };
    a.input.enabled = true; a.input.gains[4] = 2;
    a.output.enabled = true; a.output.gains[1] = 3;
    var b = { schemaVersion: 1, bandSchema: BAND_SCHEMA, id: "factory-fixture-music", revision: 1, origin: "factory", name: "Fixture Music", output: neutral() };
    b.output.enabled = true; b.output.gains[7] = -2;
    return [a, b];
}
