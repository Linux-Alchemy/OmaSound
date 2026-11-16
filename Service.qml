import QtQuick
import "models/Fixture.js" as Fixture
import "models/ProfileModel.js" as Profile
import "models/ProfileController.js" as Controller
import "models/PersistentState.js" as Persistent

QtObject {
    id: root
    // Ordinary audio controls are intentionally outside the EQ transaction.
    property var state: Fixture.initialState()
    readonly property string mode: "fixture"
    property var profileState: Controller.initialState(Date.now().toString(36) + "-" + Math.random().toString(36).slice(2))
    readonly property var effective: Controller.shown(root.queuedCandidate || root.pendingCandidate || root.profileState)
    readonly property var frequencies: Profile.FREQUENCIES
    readonly property string saveError: Controller.saveError(root.profileState)
    property bool persistenceEnabled: false
    property string stateHome: ""
    property string storageStatus: persistenceEnabled ? "loading" : "memory"
    property string storageMessage: persistenceEnabled ? "Loading saved fixture state…" : "In-memory test service"
    property double storeRevision: 0
    property int transactionSerial: 0
    property var queuedCandidate: null
    property var pendingCandidate: null
    property var pendingRequest: null
    property string operation: ""
    readonly property bool editingBlocked: persistenceEnabled && storageStatus !== "ready"
    readonly property bool eqBlocked: root.editingBlocked && !(root.storageStatus === "saving" && root.pendingRequest && !root.profileState.session)
    property var bridge: null
    property Connections bridgeSignals: Connections {
        target: root.bridge
        function onCompleted(result: var): void {
            root.storageResult(result);
        }
    }
    Component.onCompleted: {
        if (root.persistenceEnabled)
            root.reloadStorage();
    }
    signal closeApproved

    function reloadStorage(): void {
        if (root.bridge.active)
            return;
        if (root.pendingRequest) {
            root.operation = "commit";
            root.storageStatus = "saving";
            root.storageMessage = "Confirming the pending save…";
            root.bridge.request(root.pendingRequest);
        } else {
            root.operation = "load";
            root.storageStatus = "loading";
            root.storageMessage = "Loading saved fixture state…";
            root.bridge.request({
                version: 1,
                operation: "load"
            });
        }
    }

    function storageResult(result: var): void {
        result = Profile.copy(result);
        if (result && result.ok === true) {
            try {
                if (root.operation === "load") {
                    if (result.status === "absent" && result.snapshot === null) {
                        if (root.storeRevision !== 0)
                            throw new Error("Previously saved state is missing.");
                        root.storageMessage = "No saved fixture state yet. First run is neutral.";
                    } else {
                        const snap = result.snapshot;
                        if (result.status !== "loaded" || !snap || snap.version !== 1 || !Number.isSafeInteger(snap.revision) || snap.revision < 1)
                            throw new Error("Invalid storage reply.");
                        root.profileState = Persistent.restore(root.profileState, snap.value);
                        root.storeRevision = snap.revision;
                        root.storageMessage = "Loaded saved fixture profiles and EQ.";
                    }
                } else {
                    if (!root.pendingRequest || result.status !== "committed" || result.transaction !== root.pendingRequest.transaction || result.revision !== root.storeRevision + 1)
                        throw new Error("Unconfirmed save acknowledgment.");
                    const candidate = root.pendingCandidate;
                    candidate.message = "Saved fixture profiles and EQ to disk.";
                    root.profileState = candidate;
                    root.storeRevision = result.revision;
                    root.pendingCandidate = null;
                    root.pendingRequest = null;
                    root.storageMessage = "Saved fixture profiles and EQ to disk.";
                }
                root.storageStatus = "ready";
                if (root.queuedCandidate) {
                    const queued = root.queuedCandidate;
                    root.queuedCandidate = null;
                    if (Persistent.differs(root.profileState, queued)) {
                        root.beginCommit(queued);
                        return;
                    }
                }
                if (root.operation === "commit" && root.profileState.closeRequested)
                    root.closeApproved();
                return;
            } catch (_) {
                result = {
                    ok: false,
                    code: "uncertain"
                };
            }
        }
        root.queuedCandidate = null;
        const code = result && typeof result.code === "string" ? result.code : "uncertain";
        if (root.operation === "commit" && ["invalid", "oversized", "busy", "unavailable", "unsafe", "conflict"].indexOf(code) !== -1) {
            root.pendingRequest = null;
            root.pendingCandidate = null;
        }
        root.storageStatus = root.operation === "commit" && ["invalid", "oversized", "busy", "unavailable"].indexOf(code) !== -1 ? "ready" : "blocked";
        const message = code === "conflict" ? "Saved state changed elsewhere. Reload storage before retrying; your draft is retained." : (code === "uncertain" ? "Save/load result is unconfirmed. Retry storage to reconcile; your draft is retained." : "Storage rejected the operation (" + code + "). Existing files and your draft were preserved.");
        root.storageMessage = message;
        const retained = Profile.copy(root.profileState);
        retained.error = message;
        root.profileState = retained;
    }

    function beginCommit(candidate: var): void {
        try {
            const value = Persistent.value(candidate);
            Persistent.validate(value);
            root.pendingCandidate = candidate;
            root.transactionSerial++;
            root.pendingRequest = {
                version: 1,
                operation: "commit",
                expectedRevision: root.storeRevision,
                transaction: root.profileState.seed + "-" + root.transactionSerial,
                value: value
            };
            root.operation = "commit";
            root.storageStatus = "saving";
            root.storageMessage = "Saving fixture profiles and EQ…";
            root.bridge.request(root.pendingRequest);
        } catch (_) {
            root.pendingCandidate = null;
            root.pendingRequest = null;
            const failed = Profile.copy(root.profileState);
            failed.error = "Cannot save this state. Maximum 256 custom profiles; check profile values.";
            root.profileState = failed;
        }
    }

    function dispatch(action: var): void {
        // Coalesce rapid non-editor EQ movements into one latest desired state.
        // The in-flight snapshot stays immutable until its acknowledgment arrives.
        if (action.kind === "eq" && root.storageStatus === "saving" && root.pendingRequest && !root.profileState.session) {
            root.queuedCandidate = Controller.transition(root.queuedCandidate || root.pendingCandidate, action);
            return;
        }
        if (root.editingBlocked) {
            // Closing UI is safe only when no transaction or unsaved draft exists.
            if (action.kind === "close" && !root.pendingRequest && !root.bridge.active && !root.profileState.session)
                root.closeApproved();
            return;
        }
        const candidate = Controller.transition(root.profileState, action);
        if (root.persistenceEnabled && Persistent.differs(root.profileState, candidate)) {
            root.beginCommit(candidate);
        } else {
            root.profileState = candidate;
            if (root.profileState.closeRequested)
                root.closeApproved();
        }
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
        return Controller.sideLabel(root.queuedCandidate || root.pendingCandidate || root.profileState, side);
    }

    function observation(side: string): string {
        const status = (root.queuedCandidate || root.pendingCandidate || root.profileState).engine.sides[side].status;
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
