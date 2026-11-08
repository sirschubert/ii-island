pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Kill switch for the island setup. Reads ii-island/config.json.
 * enable=false restores the stock bar, music widget and notification popups.
 */
Singleton {
    id: root
    readonly property bool enabled: adapter.enable

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/ii-island/config.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool enable: true
        }
    }
}
