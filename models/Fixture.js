// Fixture-only primitives. No engine, profile schema or persistence is implied.
function acceptsPayload(payload) {
    if (typeof payload !== "string" || payload.length > 1024 || /[^\x00-\x7f]/.test(payload)) return false;
    if (payload === "") return true;
    try {
        var value = JSON.parse(payload);
        return value !== null && !Array.isArray(value) && typeof value === "object" && Object.keys(value).length === 0;
    } catch (_) { return false; }
}

function initialState() {
    return {
        input: { device: 0, devices: ["Fixture microphone", "Fixture headset mic"], volume: 60, muted: false, enabled: false, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        output: { device: 0, devices: ["Fixture speakers", "Fixture headphones"], volume: 40, muted: false, enabled: false, bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0] },
        streams: [{ name: "Fixture music player", volume: 55 }, { name: "Fixture browser", volume: 35 }]
    };
}

function change(state, side, operation, value, index) {
    if (side !== "input" && side !== "output") throw new Error("Unknown fixture side");
    var next = JSON.parse(JSON.stringify(state));
    var target = next[side];
    if (operation === "device") target.device = (target.device + 1) % target.devices.length;
    else if (operation === "mute") target.muted = !target.muted;
    else if (operation === "enabled") target.enabled = !target.enabled;
    else if (operation === "flat") target.bands = target.bands.map(function () { return 0; });
    else if (operation === "volume" && Number.isFinite(value) && value >= 0 && value <= 100) target.volume = value;
    else if (operation === "band" && Number.isInteger(index) && index >= 0 && index < 10 && Number.isFinite(value) && value >= -1 && value <= 1) target.bands[index] = value;
    else throw new Error("Invalid fixture change");
    return next;
}
