pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.island

// Connectivity watcher using NetworkManager's own check. Shows "Offline" or
// "Limited connection" in the pill, and flashes once when the link is back.
Item {
    id: root

    property bool offline: false   // last reading was none or limited
    property string shown: ""      // state the pill currently reflects, to skip redundant updates

    function onReading(state) {
        if (state === "none" || state === "limited") {
            root.offline = true;
            if (root.shown !== state) {
                root.shown = state;
                IslandState.setActivity("offline", {
                    icon: "wifi_off",
                    text: state === "none" ? "Offline" : "Limited connection",
                    color: "#e5534b",
                    priority: 90
                });
            }
        } else if (state === "full") {
            if (root.offline) {
                root.offline = false;
                root.shown = "";
                IslandState.clearActivity("offline");
                IslandState.flash("wifi", "Back online", { color: "#3fb950", ms: 2000 });
            }
        }
        // portal / unknown / empty: nmcli cannot tell yet, so keep the previous verdict.
    }

    Process {
        id: check
        command: ["nmcli", "-t", "-f", "CONNECTIVITY", "general"]
        stdout: StdioCollector {
            onStreamFinished: root.onReading(text.trim())
        }
    }

    // Faster while offline so the "Back online" flash is prompt.
    Timer {
        interval: root.offline ? 5000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!check.running)
                check.running = true;
        }
    }
}
