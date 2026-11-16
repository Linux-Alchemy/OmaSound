import QtQuick
import qs.Ui as Ui

Ui.BarWidget {
    id: root
    moduleName: "linux-alchemy.omasound-dev"
    readonly property var hostBar: root.bar
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Ui.WidgetButton {
        id: button
        bar: root.bar
        text: "EQ"
        tooltipText: "OmaSound fixture — no audio changes"
        onPressed: function (button) {
            if (button === Qt.LeftButton && root.bar && root.hostBar.shell)
                root.hostBar.shell.summon(root.moduleName, "{}");
        }
    }
}
