import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

// One player's full card: art, source, title, artist · album, progress, controls.
// Width comes from the owner (MusicCarousel delegate); it has no fixed width.
RowLayout {
    id: root
    required property var player
    spacing: 12

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player?.positionChanged()
    }

    AlbumArt {
        size: 52
        radius: 20
        source: root.player?.trackArtUrl ?? ""
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        StyledText {
            Layout.fillWidth: true
            text: root.player?.identity ?? ""
            visible: text.length > 0
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: root.player?.trackTitle || Translation.tr("Unknown Title")
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            text: [root.player?.trackArtist, root.player?.trackAlbum].filter(s => s && s.length > 0).join(" · ")
            visible: text.length > 0
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 4
            radius: 2
            color: Appearance.colors.colSecondaryContainer
            Rectangle {
                height: parent.height
                radius: 2
                color: Appearance.colors.colPrimary
                width: parent.width * ((root.player?.length ?? 0) > 0 ? Math.min(1, root.player.position / root.player.length) : 0)
            }
        }
    }
    Row {
        spacing: 2
        Repeater {
            model: [
                { icon: "skip_previous", enabled: root.player?.canGoPrevious ?? false, act: () => root.player.previous() },
                { icon: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow", enabled: root.player?.canTogglePlaying ?? false, act: () => root.player.togglePlaying() },
                { icon: "skip_next", enabled: root.player?.canGoNext ?? false, act: () => root.player.next() }
            ]
            Rectangle {
                required property var modelData
                width: 32
                height: 32
                radius: 16
                opacity: modelData.enabled ? 1 : 0.4
                color: area.containsMouse && modelData.enabled ? Appearance.colors.colLayer2Hover : "transparent"
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    iconSize: 22
                    fill: 1
                    color: Appearance.colors.colOnLayer1
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: parent.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData.act()
                }
            }
        }
    }
}
