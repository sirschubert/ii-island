pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.island

// Warns once per mount per session when a disk passes 90%. Disks fill slowly, so
// one check shortly after load and then every 10 minutes is plenty.
Item {
    id: root

    readonly property int threshold: 90
    property var warned: ({}) // mounts already warned about this session

    function onDf(output) {
        for (const line of output.split("\n")) {
            // Matches " 93% /home"; the header ("Use% Mounted on") does not match.
            const m = line.match(/^\s*(\d+)%\s+(\S.*?)\s*$/);
            if (!m)
                continue;
            const pct = parseInt(m[1]);
            const mount = m[2];
            if (pct >= root.threshold && !root.warned[mount]) {
                root.warned[mount] = true;
                IslandState.pushCard("disk-" + mount, {
                    icon: "hard_drive",
                    title: "Disk almost full",
                    body: mount + " is " + pct + "% full",
                    accent: "#e5534b",
                    ttl: 8000
                });
            }
        }
    }

    Process {
        id: df
        command: ["df", "--output=pcent,target", "/", "/home"]
        stdout: StdioCollector {
            onStreamFinished: root.onDf(text)
        }
    }

    function check() {
        if (!df.running)
            df.running = true;
    }

    // One-shot: first check ~30 s after load, so the shell is settled.
    Timer {
        interval: 30000
        running: true
        onTriggered: root.check()
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.check()
    }
}
