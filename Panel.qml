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

    function close(): void {
        root.closingFromHost = true;
        window.visible = false;
        root.closingFromHost = false;
    }

    function requestClose(): void {
        if (root.shell)
            root.shell.hide("linux-alchemy.omasound-dev");
        else
            root.close();
    }

    // Small read-only diagnostic for tools/preview; never an audio command path.
    function status(unused: string): string {
        return JSON.stringify({
            mode: "fixture",
            visible: root.opened,
            instance: root.instanceId,
            opens: root.openCount,
            ready: !!root.service && root.service.mode === "fixture",
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
            if (!visible && !root.closingFromHost && root.shell)
                root.shell.hide("linux-alchemy.omasound-dev");
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
                text: "Profiles and live EQ arrive in later phases. Close preserves this fixture until preview stop."
            }
        }
    }
}
