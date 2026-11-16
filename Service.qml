import QtQuick
import "models/Fixture.js" as Fixture

QtObject {
    id: root
    property var state: Fixture.initialState()
    readonly property string mode: "fixture"

    function change(side: string, operation: string, value: real, index: int): void {
        root.state = Fixture.change(root.state, side, operation, value, index);
    }

    function setStreamVolume(index: int, value: real): void {
        if (index < 0 || index >= root.state.streams.length || !Number.isFinite(value) || value < 0 || value > 100)
            return;
        const next = JSON.parse(JSON.stringify(root.state));
        next.streams[index].volume = value;
        root.state = next;
    }
}
