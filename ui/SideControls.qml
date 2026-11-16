pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property string side
    required property var service
    readonly property var sideState: service ? service.state[side] : null
    readonly property var eq: service ? service.effective[side].eq : null
    readonly property bool editable: !!service && !service.profileState.pendingAction && (!service.profileState.session || service.profileState.session.included[side])
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
        enabled: root.editable
        Action {
            text: root.eq && root.eq.enabled ? "EQ fixture: on" : "EQ fixture: off"
            onClicked: root.service.eqChange(root.side, "enabled", !root.eq.enabled, 0)
        }
        Action {
            text: "Flat"
            onClicked: root.service.eqChange(root.side, "flat", 0, 0)
        }
        Label {
            Layout.fillWidth: true
            text: "±12 dB · fixture only"
        }
    }
    Label {
        Layout.fillWidth: true
        text: root.service ? root.service.sideLabel(root.side) + " · " + root.service.observation(root.side) : ""
    }
    Label {
        Layout.fillWidth: true
        visible: !!root.service && !!root.service.profileState.session && !root.service.profileState.session.included[root.side]
        text: "Include this side to edit its EQ. Its current settings are preserved."
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !root.service || !root.service.profileState.session || root.service.profileState.session.included[root.side]
        enabled: root.editable
        uniformCellSizes: true
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
                    from: -12
                    to: 12
                    stepSize: 0.5
                    value: root.eq ? root.eq.gains[band.index] : 0
                    Accessible.name: root.side + " fixture band " + (band.index + 1)
                    onMoved: root.service.eqChange(root.side, "gain", value, band.index)
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.service ? (root.service.frequencies[band.index] >= 1000 ? root.service.frequencies[band.index] / 1000 + "k" : String(root.service.frequencies[band.index])) : ""
                    font.pixelSize: 12
                }
            }
        }
    }
}
