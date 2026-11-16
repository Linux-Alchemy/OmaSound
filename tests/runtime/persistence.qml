import QtQuick
import Quickshell
import "." as App

QtObject {
    id: root
    property var service: null
    property var other: null
    property string home: Quickshell.env("OMASOUND_TEST_STATE_HOME")
    property var steps: []
    property int cursor: 0
    property int ticks: 0
    property int passes: 0
    property int closed: 0
    property var oldState: null
    property var request: null
    property var candidate: null
    property Component factory: Component {
        App.RuntimeService {}
    }
    property Connections closing: Connections {
        target: root.service
        function onCloseApproved(): void {
            root.closed++;
        }
    }
    function check(value, message) {
        if (!value)
            throw new Error(message);
    }
    function create() {
        service = factory.createObject(root, {
            stateHome: home
        });
        check(service !== null, "Create service");
    }
    function ready() {
        return service.storageStatus === "ready";
    }
    function saved() {
        if (!ready())
            return false;
        check(service.storageMessage.indexOf("Saved") !== -1, service.storageMessage);
    }
    function restart() {
        service.destroy();
        create();
    }
    function draft() {
        service.dispatch({
            kind: "new"
        });
        service.dispatch({
            kind: "draft",
            change: {
                kind: "name",
                value: "Saved <b>profile</b>"
            }
        });
        service.dispatch({
            kind: "draft",
            change: {
                kind: "include",
                side: "output",
                value: true
            }
        });
        service.eqChange("output", "gain", 11.5, 9);
    }
    function pass(name) {
        root.passes++;
        console.log("OMASOUND_TEST_PASS", name);
    }
    Component.onCompleted: {
        check(home !== "", "Disposable state home required");
        steps = [() => create(), ready, () => {
                check(service.storeRevision === 0, "Neutral first run");
                service.dispatch({
                    kind: "apply",
                    id: "factory-fixture-gaming"
                });
            }, saved, () => service.dispatch({
                    kind: "apply",
                    id: "factory-fixture-music"
                }), saved, () => {
                draft();
                service.change("output", "volume", 27, 0);
                service.dispatch({
                    kind: "cancel"
                });
                check(service.state.output.volume === 27, "Cancel preserved volume");
                restart();
            }, ready, () => {
                check(service.sideLabel("input") === "Fixture Gaming" && service.sideLabel("output") === "Fixture Music", "Mixed source recovery");
                check(service.effective.input.eq.gains[4] === 2, "Input EQ recovery");
                pass("mixed profiles and Cancel survive restart");
                draft();
                restart();
            }, ready, () => {
                check(service.profileState.profiles.length === 2 && service.effective.output.eq.gains[9] === 0, "Abandoned draft absent");
                pass("abandoned draft never persisted");
                draft();
                service.dispatch({
                    kind: "close"
                });
                service.dispatch({
                    kind: "resolve",
                    choice: "save"
                });
                check(closed === 0 && service.profileState.session !== null, "Close waits for durable Save");
            }, saved, () => {
                check(closed === 1, "Close after ack");
                restart();
            }, ready, () => {
                check(service.profileState.profiles.length === 3 && service.effective.output.eq.gains[9] === 11.5, "Latest draft stored");
                pass("Save acknowledgment and latest draft recovery");
                service.dispatch({
                    kind: "edit",
                    id: service.profileState.profiles[2].id
                });
                service.eqChange("output", "gain", 8, 9);
                service.dispatch({
                    kind: "close"
                });
                service.stateHome = "/proc/omasound-fixture-test-unavailable";
                service.dispatch({
                    kind: "resolve",
                    choice: "save"
                });
            }, ready, () => {
                check(service.profileState.session.dirty && service.profileState.pendingAction.kind === "close" && closed === 1, "Failed Save retains pending close");
                service.stateHome = home;
                service.dispatch({
                    kind: "resolve",
                    choice: "save"
                });
            }, saved, () => {
                check(closed === 2, "Retry close");
                pass("failed Save retains draft and pending close");
                other = factory.createObject(root, {
                    stateHome: home
                });
            }, () => other.storageStatus === "ready", () => other.eqChange("input", "gain", 5, 0), () => other.storageStatus === "ready", () => {
                check(other.storeRevision > service.storeRevision, "Second writer committed");
                other.destroy();
                other = null;
                service.dispatch({
                    kind: "edit",
                    id: service.profileState.profiles[2].id
                });
                service.eqChange("output", "gain", 6, 9);
                service.dispatch({
                    kind: "save"
                });
            }, () => service.storageStatus === "blocked", () => {
                check(service.profileState.session.dirty, "Conflict preserved draft");
                service.reloadStorage();
            }, ready, () => {
                check(service.effective.input.eq.gains[0] === 5 && service.profileState.session.dirty, "Reload retains independent input and draft");
                service.dispatch({
                    kind: "save"
                });
            }, saved, () => {
                pass("concurrent conflict and explicit reload");
                service.dispatch({
                    kind: "edit",
                    id: service.profileState.profiles[2].id
                });
                service.eqChange("output", "gain", 7, 9);
                oldState = JSON.parse(JSON.stringify(service.profileState));
                service.dispatch({
                    kind: "save"
                });
                request = JSON.parse(JSON.stringify(service.pendingRequest));
                candidate = JSON.parse(JSON.stringify(service.pendingCandidate));
            }, saved, () => {
                service.profileState = oldState;
                service.storeRevision = request.expectedRevision;
                service.pendingRequest = request;
                service.pendingCandidate = candidate;
                service.operation = "commit";
                service.storageResult({
                    ok: false,
                    code: "uncertain"
                });
                check(service.storageStatus === "blocked" && service.profileState.session.dirty, "Lost ack protects draft");
                service.reloadStorage();
            }, saved, () => {
                check(service.storeRevision === request.expectedRevision + 1, "Idempotent retry revision");
                restart();
            }, ready, () => {
                check(service.profileState.profiles.length === 3 && service.effective.output.eq.gains[9] === 7, "Idempotent retry snapshot");
                pass("lost acknowledgment reconciled by same transaction");
                service.eqChange("input", "gain", 1, 0);
                service.eqChange("input", "gain", 2, 0);
                service.eqChange("input", "gain", 3.5, 0);
                check(service.effective.input.eq.gains[0] === 3.5, "Rapid changes preview latest");
            }, saved, () => restart(), ready, () => {
                check(service.effective.input.eq.gains[0] === 3.5, "Rapid changes persist latest");
                pass("coalesced rapid EQ persists final movement");
                console.log("OMASOUND_TEST_COMPLETE", passes);
                Qt.quit();
            }];
        runner.start();
    }
    property Timer runner: Timer {
        id: runner
        interval: 20
        repeat: true
        onTriggered: {
            try {
                if (++root.ticks > 400)
                    throw new Error("Step timed out: " + root.cursor + " " + (root.service ? root.service.storageMessage : ""));
                if (root.steps[root.cursor]() !== false) {
                    root.cursor++;
                    root.ticks = 0;
                }
            } catch (error) {
                console.error("OMASOUND_TEST_FAIL", root.cursor, String(error));
                runner.stop();
                Qt.quit();
            }
        }
    }
}
