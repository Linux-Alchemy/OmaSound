pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var service
    property string selectedId: "factory-fixture-gaming"
    readonly property var modelState: service ? service.profileState : null
    readonly property var session: modelState ? modelState.session : null
    readonly property bool prompting: !!(modelState && modelState.pendingAction)
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        enabled: !root.prompting && root.service && !root.service.editingBlocked
        Controls.ComboBox {
            id: picker
            Layout.fillWidth: true
            model: root.modelState ? root.modelState.profiles : []
            textRole: "name"
            valueRole: "id"
            currentIndex: root.modelState ? Math.max(0, root.modelState.profiles.findIndex(function (p) {
                return p.id === root.selectedId;
            })) : -1
            onActivated: root.selectedId = String(currentValue)
            contentItem: Label {
                text: picker.displayText
                verticalAlignment: Text.AlignVCenter
                leftPadding: 8
                rightPadding: 28
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            delegate: Controls.ItemDelegate {
                id: choice
                required property var modelData
                width: picker.width
                contentItem: Label {
                    text: choice.modelData.name
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
        Action {
            text: "Apply"
            onClicked: root.service.dispatch({
                kind: "apply",
                id: root.selectedId
            })
        }
        Action {
            text: "Edit / copy"
            onClicked: root.service.dispatch({
                kind: "edit",
                id: root.selectedId
            })
        }
        Action {
            text: "New profile"
            onClicked: root.service.dispatch({
                kind: "new"
            })
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!root.session
        enabled: !root.prompting && root.service && !root.service.editingBlocked
        Controls.TextField {
            Layout.fillWidth: true
            maximumLength: 256
            placeholderText: "Profile name"
            text: root.session ? root.session.name : ""
            Accessible.name: "Profile name"
            onTextEdited: root.service.dispatch({
                kind: "draft",
                change: {
                    kind: "name",
                    value: text
                }
            })
        }
        Action {
            text: root.session && root.session.included.output ? "☑ Output settings" : "☐ Output settings"
            onClicked: root.service.dispatch({
                kind: "draft",
                change: {
                    kind: "include",
                    side: "output",
                    value: !root.session.included.output
                }
            })
        }
        Action {
            text: root.session && root.session.included.input ? "☑ Input settings" : "☐ Input settings"
            onClicked: root.service.dispatch({
                kind: "draft",
                change: {
                    kind: "include",
                    side: "input",
                    value: !root.session.included.input
                }
            })
        }
        Action {
            text: "Save"
            enabled: root.service && !root.service.editingBlocked && root.service.saveError === ""
            onClicked: root.service.dispatch({
                kind: "save"
            })
        }
        Action {
            text: "Cancel"
            onClicked: root.service.dispatch({
                kind: "cancel"
            })
        }
    }
    Label {
        Layout.fillWidth: true
        visible: !!root.session
        text: root.service && root.service.saveError ? root.service.saveError : (root.session && root.session.dirty ? "Unsaved changes · included sides preview immediately in the fixture" : "Editing · no unsaved changes")
    }
    RowLayout {
        visible: root.prompting
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: "Unsaved changes — save, discard, or keep editing?"
            font.bold: true
        }
        Action {
            text: "Save"
            enabled: root.service && !root.service.editingBlocked && root.service.saveError === ""
            onClicked: root.service.dispatch({
                kind: "resolve",
                choice: "save"
            })
        }
        Action {
            enabled: root.service && !root.service.editingBlocked
            text: "Discard"
            onClicked: root.service.dispatch({
                kind: "resolve",
                choice: "discard"
            })
        }
        Action {
            enabled: root.service && !root.service.editingBlocked
            text: "Keep editing"
            onClicked: root.service.dispatch({
                kind: "resolve",
                choice: "keep"
            })
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Label {
            Layout.fillWidth: true
            text: root.service ? root.service.storageMessage : "Loading storage…"
        }
        Action {
            text: "Retry / reload storage"
            visible: root.service && root.service.storageStatus === "blocked"
            enabled: root.service && !root.service.bridge.active
            onClicked: root.service.reloadStorage()
        }
    }
    Label {
        Layout.fillWidth: true
        text: root.modelState ? (root.modelState.error || root.modelState.message) : "Loading profiles…"
        font.bold: !!(root.modelState && root.modelState.error)
    }
}
