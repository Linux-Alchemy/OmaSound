import QtQuick
import "models/Fixture.js" as Fixture
import "models/ProfileModel.js" as Profile
import "models/ProfileController.js" as Controller

QtObject {
    id: root
    // Ordinary audio controls are intentionally outside the EQ transaction.
    property var state: Fixture.initialState()
    readonly property string mode: "fixture"
    property var profileState: Controller.initialState(Date.now().toString(36) + "-" + Math.random().toString(36).slice(2))
    readonly property var effective: Controller.shown(root.profileState)
    readonly property var frequencies: Profile.FREQUENCIES
    readonly property string saveError: Controller.saveError(root.profileState)
    signal closeApproved

    function dispatch(action: var): void {
        root.profileState = Controller.transition(root.profileState, action);
        if (root.profileState.closeRequested)
            root.closeApproved();
    }

    function change(side: string, operation: string, value: real, index: int): void {
        if (["device", "volume", "mute"].indexOf(operation) !== -1)
            root.state = Fixture.change(root.state, side, operation, value, index);
    }

    function eqChange(side: string, kind: string, value: var, index: int): void {
        root.dispatch({
            kind: "eq",
            side: side,
            change: {
                kind: kind,
                value: value,
                index: index
            }
        });
    }

    function sideLabel(side: string): string {
        return Controller.sideLabel(root.profileState, side);
    }

    function observation(side: string): string {
        const status = root.profileState.engine.sides[side].status;
        if (status === "simulated")
            return "Applied to fixture only";
        if (status === "waiting")
            return "Waiting for fixture device";
        if (status === "failed-restored")
            return "Apply failed; previous EQ restored";
        if (status === "uncertain")
            return "Apply/restore unconfirmed — EQ uncertain";
        return "Fixture update pending";
    }

    function setStreamVolume(index: int, value: real): void {
        if (index < 0 || index >= root.state.streams.length || !Number.isFinite(value) || value < 0 || value > 100)
            return;
        const next = JSON.parse(JSON.stringify(root.state));
        next.streams[index].volume = value;
        root.state = next;
    }
}
