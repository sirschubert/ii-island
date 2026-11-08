import QtQuick
import qs.modules.common
import qs.modules.common.widgets

// Icon + text that slides: when `key` changes, the old content moves up and fades
// out while the new one rises in from below. Text changes with the same key
// (e.g. a ticking clock) update in place without animating.
Item {
    id: root
    property string key: ""
    property string icon: ""
    property string text: ""
    property var graph: [] // optional 0..1 values drawn as a tiny sparkline after the text
    property color iconColor: Appearance.colors.colPrimary
    property color textColor: Appearance.colors.colOnLayer1
    property int pixelSize: Appearance.font.pixelSize.small
    property bool center: false
    clip: true

    property int current: 0
    readonly property Item front: current === 0 ? slotA : slotB

    function swap() {
        const incoming = current === 0 ? slotB : slotA;
        const outgoing = current === 0 ? slotA : slotB;
        incoming.icon = root.icon;
        incoming.text = root.text;
        incoming.graph = root.graph;
        anim.incoming = incoming;
        anim.outgoing = outgoing;
        anim.restart();
        current = 1 - current;
    }
    onKeyChanged: swap()
    onIconChanged: front.icon = icon
    onTextChanged: front.text = text
    onGraphChanged: front.graph = graph
    Component.onCompleted: {
        slotA.icon = icon;
        slotA.text = text;
        slotA.graph = graph;
    }
    // After a slide, pin the front slot in place (in case the size changed mid-animation).
    Connections {
        target: anim
        function onFinished() {
            root.front.y = 0;
            root.front.opacity = 1;
        }
    }

    component Slot: Row {
        id: slotRow
        property string icon: ""
        property string text: ""
        property var graph: []
        width: root.center ? implicitWidth : root.width
        x: root.center ? (root.width - implicitWidth) / 2 : 0
        spacing: 7
        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.icon !== ""
            text: parent.icon
            iconSize: 18
            fill: 1
            color: root.iconColor
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            width: root.center ? implicitWidth : Math.max(0, parent.width - (parent.icon !== "" ? 25 : 0) - (slotRow.graph.length > 0 ? 40 : 0))
            text: parent.text
            elide: Text.ElideRight
            font.pixelSize: root.pixelSize
            color: root.textColor
        }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: slotRow.graph.length > 0
            spacing: 1
            height: 14
            Repeater {
                model: slotRow.graph
                Rectangle {
                    required property real modelData
                    anchors.bottom: parent.bottom
                    width: 2
                    radius: 1
                    height: 2 + 12 * Math.max(0, Math.min(1, modelData))
                    color: root.iconColor
                    opacity: 0.85
                }
            }
        }
    }

    Slot {
        id: slotA
        height: root.height
    }
    Slot {
        id: slotB
        height: root.height
        opacity: 0
        // Hidden by opacity, not by a `y: root.height` binding: animations don't
        // remove bindings, so a height change (the island resizing) would push a
        // visible slot back out of view.
    }

    ParallelAnimation {
        id: anim
        property Item incoming
        property Item outgoing
        NumberAnimation { target: anim.outgoing; property: "y"; to: -root.height * 0.8; duration: 320; easing.type: Easing.InCubic }
        NumberAnimation { target: anim.outgoing; property: "opacity"; to: 0; duration: 260 }
        NumberAnimation { target: anim.incoming; property: "y"; from: root.height * 0.8; to: 0; duration: 380; easing.type: Easing.OutCubic }
        NumberAnimation { target: anim.incoming; property: "opacity"; from: 0; to: 1; duration: 320 }
    }
}
