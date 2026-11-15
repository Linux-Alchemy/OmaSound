pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property string side
    required property var service
    readonly property var sideState: service ? service.state[side] : null
    spacing: 12

    Label {
        text: root.side === "output" ? "Output" : "Input"
        font.pixelSize: 22
    }
    RowLayout {
        Layout.fillWidth: true
        Action {
            Layout.fillWidth: true
            text: root.sideState ? root.sideState.devices[root.sideState.device] : "Waiting for fixture"
            onClicked: root.service.change(root.side, "device", 0, 0)
        }
        Action {
            text: root.sideState && root.sideState.muted ? "Unmute" : "Mute"
            onClicked: root.service.change(root.side, "mute", 0, 0)
        }
        Label {
            text: root.sideState ? Math.round(root.sideState.volume) + "%" : ""
            Layout.preferredWidth: 48
        }
    }
    Controls.Slider {
        Layout.fillWidth: true
        from: 0
        to: 100
        value: root.sideState ? root.sideState.volume : 0
        Accessible.name: root.side + " fixture volume"
        onMoved: root.service.change(root.side, "volume", value, 0)
    }
    RowLayout {
        Action {
            text: root.sideState && root.sideState.enabled ? "EQ fixture: on" : "EQ fixture: off"
            onClicked: root.service.change(root.side, "enabled", 0, 0)
        }
        Action {
            text: "Flat"
            onClicked: root.service.change(root.side, "flat", 0, 0)
        }
        Label {
            Layout.fillWidth: true
            text: "Demonstration bands · no frequencies or gain scale selected"
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: 10
            ColumnLayout {
                id: band
                required property int index
                Layout.fillWidth: true
                Controls.Slider {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 125
                    orientation: Qt.Vertical
                    from: -1
                    to: 1
                    value: root.sideState ? root.sideState.bands[band.index] : 0
                    Accessible.name: root.side + " fixture band " + (band.index + 1)
                    onMoved: root.service.change(root.side, "band", value, band.index)
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(band.index + 1)
                }
            }
        }
    }
}
