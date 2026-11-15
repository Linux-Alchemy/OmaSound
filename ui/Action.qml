import QtQuick
import QtQuick.Controls as Controls
import qs.Commons as Commons

Controls.Button {
    id: root
    padding: 10
    contentItem: Label {
        text: root.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 6
        color: root.down ? Commons.Color.accent : Commons.Color.background
        border.color: root.activeFocus ? Commons.Color.accent : Commons.Color.foreground
        border.width: root.activeFocus ? 2 : 1
        opacity: root.hovered ? 1 : 0.8
    }
}
