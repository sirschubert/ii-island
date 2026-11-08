pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.modules.island

// Screen recording indicator. record.sh (or its keybind) starts and stops wf-recorder;
// this only watches the process, so it works however the recording was started.
Item {
    id: root

    readonly property string activityId: "recording"
    property bool recording: false
    property double startedAt: 0 // ms, when we first saw wf-recorder running

    function mmss(totalSeconds) {
        const m = Math.floor(totalSeconds / 60);
        const s = totalSeconds % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function onPoll(isRunning) {
        if (isRunning && !root.recording) {
            root.recording = true;
            root.startedAt = Date.now();
        } else if (!isRunning && root.recording) {
            // Only a real running -> stopped transition flashes; startup never does.
            root.recording = false;
            IslandState.clearActivity(root.activityId);
            IslandState.flash("movie", "Recording saved", { ms: 2500 });
            return;
        }

        if (root.recording) {
            const elapsed = Math.floor((Date.now() - root.startedAt) / 1000);
            // Clicking the pill stops the recording the same way the keybind does.
            IslandState.setActivity(root.activityId, {
                icon: "radio_button_checked",
                text: "REC " + root.mmss(elapsed),
                color: "#e5534b",
                priority: 80,
                command: ["bash", "-c", "pkill -INT wf-recorder"]
            });
        }
    }

    // pgrep exits 0 when a match exists.
    Process {
        id: pgrep
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: exitCode => root.onPoll(exitCode === 0)
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!pgrep.running)
                pgrep.running = true;
        }
    }
}
