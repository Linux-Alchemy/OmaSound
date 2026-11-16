import QtQuick
import "adapters" as Adapters

Service {
    id: root
    persistenceEnabled: true
    bridge: Adapters.StateBridge {
        stateHome: root.stateHome
    }
}
