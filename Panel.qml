pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Commons as Commons
import "ui" as Ui
import "models/Fixture.js" as Fixture

// Host lifecycle pattern adapted from Omarchy's dev gallery; see notices.
Item {
    id: root
    property var shell: null
    property var service: null
    property bool closingFromHost: false
    property bool allowClose: false
    property int openCount: 0
    readonly property bool opened: window.visible
    readonly property string instanceId: Date.now().toString() + "-" + Math.random().toString(16).slice(2)

    function open(payloadJson: string): void {
        if (!Fixture.acceptsPayload(payloadJson)) {
            if (!root.opened && root.shell)
                root.shell.hide("linux-alchemy.omasound-dev");
            return;
        }
        root.openCount++;
        window.minimized = false;
        window.visible = true;
        Qt.callLater(function () {
            if (root.opened && contents.Window.window) {
                contents.Window.window.raise();
                contents.Window.window.requestActivate();
            }
        });
    }

    function hideApproved(): void {
        root.allowClose = true;
        if (root.shell)
            root.shell.hide("linux-alchemy.omasound-dev");
        root.closingFromHost = true;
        window.visible = false;
        root.closingFromHost = false;
        root.allowClose = false;
    }

    function close(): void {
        if (root.allowClose) {
            window.visible = false;
            return;
        }
        root.requestClose();
    }

    function requestClose(): void {
        if (root.service)
            root.service.dispatch({
                kind: "close"
            });
        else
            root.hideApproved();
    }

    Connections {
        target: root.service
        function onCloseApproved(): void {
            root.hideApproved();
        }
    }

    Connections {
        target: contents.Window.window
        function onClosing(event): void {
            if (!root.allowClose) {
                event.accepted = false;
                root.requestClose();
            }
        }
    }

    // Small read-only diagnostic for tools/preview; never an audio command path.
    function status(unused: string): string {
        return JSON.stringify({
            mode: "fixture",
            sourceUrl: String(Qt.resolvedUrl("Panel.qml")),
            visible: root.opened,
            instance: root.instanceId,
            opens: root.openCount,
            ready: !!root.service && root.service.mode === "fixture" && root.service.storageStatus !== "loading",
            effective: root.service ? root.service.effective : null,
            dirty: !!root.service && !!root.service.profileState.session && root.service.profileState.session.dirty,
            prompt: !!root.service && !!root.service.profileState.pendingAction,
            storage: root.service ? root.service.storageStatus : "loading",
            revision: root.service ? root.service.storeRevision : 0,
            profiles: root.service ? root.service.profileState.profiles.length : 0,
            width: window.width,
            height: window.height
        });
    }

    FloatingWindow {
        id: window
        visible: false
        title: "OmaSound — Fixture"
        color: Commons.Color.background
        implicitWidth: 1200
        implicitHeight: 800
        // Fixed only for the baseline fixture; final sizing is a later decision.
        minimumSize: Qt.size(1200, 800)
        maximumSize: Qt.size(1200, 800)
        onVisibleChanged: {
            if (!visible && !root.closingFromHost && !root.allowClose) {
                // Fallback for a compositor/platform that hides before closing.
                if (root.service && root.service.profileState.session && root.service.profileState.session.dirty)
                    window.visible = true;
                root.requestClose();
            }
        }

        ColumnLayout {
            id: contents
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18
            RowLayout {
                Layout.fillWidth: true
                Ui.Label {
                    Layout.fillWidth: true
                    text: "OmaSound / fixture workbench"
                    font.pixelSize: 28
                    MouseArea {
                        anchors.fill: parent
                        onPressed: window.startSystemMove()
                    }
                }
                Ui.Action {
                    text: "Close"
                    onClicked: root.requestClose()
                }
            }
            Ui.Label {
                Layout.fillWidth: true
                text: "Synthetic devices and controls. Your sound is untouched. This arrangement is temporary."
            }
            Ui.ProfileEditor {
                Layout.fillWidth: true
                service: root.service
            }
            Controls.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                ColumnLayout {
                    width: parent.width
                    spacing: 22
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 32
                        Ui.SideControls {
                            Layout.fillWidth: true
                            side: "output"
                            service: root.service
                        }
                        Ui.SideControls {
                            Layout.fillWidth: true
                            side: "input"
                            service: root.service
                        }
                    }
                    Ui.Label {
                        text: "Application volume / fixtures"
                        font.pixelSize: 22
                    }
                    Repeater {
                        model: root.service ? root.service.state.streams.length : 0
                        RowLayout {
                            id: stream
                            required property int index
                            readonly property var streamState: root.service.state.streams[stream.index]
                            Layout.fillWidth: true
                            Ui.Label {
                                text: stream.streamState.name
                                Layout.preferredWidth: 230
                            }
                            Controls.Slider {
                                Layout.fillWidth: true
                                from: 0
                                to: 100
                                value: stream.streamState.volume
                                Accessible.name: stream.streamState.name + " volume"
                                onMoved: root.service.setStreamVolume(stream.index, value)
                            }
                            Ui.Label {
                                text: Math.round(stream.streamState.volume) + "%"
                                Layout.preferredWidth: 50
                            }
                        }
                    }
                }
            }
            Ui.Label {
                text: "Saved fixture profiles and EQ survive preview restart. Unsaved drafts do not. Live audio is untouched."
            }
        }
    }
}
