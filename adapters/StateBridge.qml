import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("../helpers/omasound_helper.py")).replace(/^file:\/\//, ""))
    property string stateHome: ""
    readonly property var processEnvironment: root.stateHome ? ({
            XDG_STATE_HOME: root.stateHome
        }) : ({})
    property bool active: false
    property string input: ""
    signal completed(var result)

    function finish(result: var): void {
        if (!root.active)
            return;
        root.active = false;
        deadline.stop();
        root.completed(result);
    }

    function request(value: var): void {
        if (root.active)
            return;
        root.input = JSON.stringify(value);
        // JSON is sent through stdin, never shell arguments. UTF-8 upper bound.
        if (root.input.length * 3 > 1024 * 1024) {
            root.completed({
                ok: false,
                code: "oversized"
            });
            return;
        }
        root.active = true;
        worker.stdinEnabled = true;
        worker.running = true;
        deadline.start();
    }

    property Process processHandle: Process {
        id: worker
        command: ["/usr/bin/python3", "-B", root.helperPath]
        environment: root.processEnvironment
        onStarted: {
            worker.write(root.input);
            worker.stdinEnabled = false;
        }
        stdout: StdioCollector {
            id: output
            waitForEnd: true
        }
        // Helper emits one pre-bounded reply, no stderr and no child processes.
        onExited: function (exitCode, exitStatus) {
            if (!root.active)
                return;
            try {
                if (exitCode !== 0 || exitStatus !== 0 || output.text.length > 1024 * 1024)
                    throw new Error("Unconfirmed helper result");
                root.finish(JSON.parse(output.text));
            } catch (_) {
                root.finish({
                    ok: false,
                    code: "uncertain"
                });
            }
        }
    }
    property Timer deadlineTimer: Timer {
        id: deadline
        interval: 6000
        onTriggered: {
            if (worker.running)
                worker.signal(9);
            root.finish({
                ok: false,
                code: "uncertain"
            });
        }
    }
    Component.onDestruction: {
        if (worker.running)
            worker.signal(9);
    }
}
