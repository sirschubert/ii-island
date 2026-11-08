pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.island

// Flags a process that keeps a core busy: >= 90% CPU on 3 polls in a row (about 30 s), with an info
// card offering Kill. top runs twice so the CPU figures are a real sample, not the average since boot.
Item {
    id: root

    readonly property int pollMs: 10000
    readonly property real hotPercent: 90
    readonly property int hotPolls: 3
    // Compositor, shell, and the sampler itself: never flagged.
    readonly property var ignored: ["top", "kwin", "Hyprland", "qs", "quickshell"]

    // pid -> { name, count } for the processes that were hot in the last poll.
    property var hot: ({})
    // pid -> true once warned. Cleared when the pid cools off, so a later spike warns again.
    property var warned: ({})

    function onSample(text) {
        const next = {};
        const nextWarned = {};
        for (const line of text.trim().split("\n")) {
            const f = line.trim().split(/\s+/);
            if (f.length < 3)
                continue;
            const pid = f[0];
            const cpu = parseFloat(f[1]);
            const name = f[2];
            if (!(cpu >= root.hotPercent) || root.ignored.indexOf(name) >= 0)
                continue;
            const prev = root.hot[pid];
            // A pid reused by another program starts counting again.
            const count = prev && prev.name === name ? prev.count + 1 : 1;
            next[pid] = { name: name, count: count };
            if (root.warned[pid]) {
                nextWarned[pid] = true;
            } else if (count >= root.hotPolls) {
                nextWarned[pid] = true;
                IslandState.pushCard("cpu-" + pid, {
                    icon: "local_fire_department",
                    title: name + " is using " + Math.round(cpu) + "% CPU",
                    body: "for over 30 seconds",
                    accent: "#e5534b",
                    ttl: 12000,
                    actions: [
                        { text: "Kill", command: ["kill", String(pid)] },
                        { text: "Ignore", command: ["true"] }
                    ]
                });
            }
        }
        root.hot = next;
        root.warned = nextWarned;
    }

    Process {
        id: sampler
        command: ["sh", "-c", "top -b -n 2 -d 0.5 -w 512 | awk '/^top -/{f++} f==2 && $1 ~ /^[0-9]+$/ {print $1, $9, $12}' | sort -k2 -nr | head -3"]
        stdout: StdioCollector {
            onStreamFinished: root.onSample(text)
        }
    }

    // Never start a sample while the previous one still runs (it takes about a second).
    Timer {
        interval: root.pollMs
        running: true
        repeat: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
        }
    }
}
