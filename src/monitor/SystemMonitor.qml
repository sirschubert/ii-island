pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.island.monitor

/**
 * Left slide-in system monitor, replacing the AI sidebar. Uses the AI sidebar's
 * layer namespace so Hyprland's existing slide animation applies unchanged.
 */
Scope {
    id: root

    function gb(kb) {
        return (kb / 1048576).toFixed(1);
    }

    PanelWindow {
        id: panelWindow
        visible: SystemMonitorService.open
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

        exclusiveZone: 0
        implicitWidth: 310 + Appearance.sizes.elevationMargin * 2
        WlrLayershell.namespace: "quickshell:sidebarLeft"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        color: "transparent"

        anchors {
            top: true
            left: true
            bottom: true
        }

        mask: Region {
            item: background
        }

        onVisibleChanged: {
            if (visible)
                GlobalFocusGrab.addDismissable(panelWindow);
            else
                GlobalFocusGrab.removeDismissable(panelWindow);
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                SystemMonitorService.open = false;
            }
        }

        StyledRectangularShadow {
            target: background
        }
        Rectangle {
            id: background
            anchors {
                fill: parent
                topMargin: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.hyprlandGapsOut
                bottomMargin: Appearance.sizes.hyprlandGapsOut
                rightMargin: Appearance.sizes.elevationMargin
            }
            radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
            color: Appearance.colors.colLayer1Base
            focus: true
            Keys.onEscapePressed: SystemMonitorService.open = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                RowLayout {
                    Layout.bottomMargin: 4
                    MaterialSymbol {
                        text: "monitoring"
                        iconSize: 24
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "System monitor"
                        font.pixelSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                }

                MonitorCard {
                    icon: "memory"
                    title: "CPU"
                    value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                    history: ResourceUsage.cpuUsageHistory
                    footerLeft: SystemMonitorService.cpuFreq > 0 ? (SystemMonitorService.cpuFreq / 1000).toFixed(1) + " GHz" : ""
                    footerRight: SystemMonitorService.cpuTemp >= 0 ? Math.round(SystemMonitorService.cpuTemp) + " °C" : ""
                }
                MonitorCard {
                    visible: SystemMonitorService.gpuAvailable
                    icon: "developer_board"
                    title: SystemMonitorService.gpu?.name ?? "GPU"
                    value: (SystemMonitorService.gpu?.util ?? 0) + "%"
                    history: SystemMonitorService.gpuHistory
                    graphColor: Appearance.colors.colTertiary
                    footerLeft: SystemMonitorService.gpu ? "VRAM " + (SystemMonitorService.gpu.memUsedMiB / 1024).toFixed(1) + " / " + (SystemMonitorService.gpu.memTotalMiB / 1024).toFixed(1) + " GB" : ""
                    footerRight: SystemMonitorService.gpu ? SystemMonitorService.gpu.tempC + " °C" : ""
                }
                MonitorCard {
                    icon: "memory_alt"
                    title: "Memory"
                    value: root.gb(ResourceUsage.memoryUsed) + " GB"
                    barFraction: ResourceUsage.memoryUsedPercentage
                    footerLeft: "of " + root.gb(ResourceUsage.memoryTotal) + " GB"
                    footerRight: ResourceUsage.swapTotal > 1 ? "swap " + root.gb(ResourceUsage.swapUsed) + " GB" : ""
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: procCol.implicitHeight + 24
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colLayer2
                    ColumnLayout {
                        id: procCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4
                        RowLayout {
                            StyledText {
                                Layout.fillWidth: true
                                text: "Top processes"
                                color: Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                text: "CPU"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }
                        }
                        Repeater {
                            model: SystemMonitorService.procs
                            RowLayout {
                                required property var modelData
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledText {
                                    text: modelData.cpu.toFixed(1) + "%"
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    IpcHandler {
        target: "systemMonitor"
        function toggle(): void { SystemMonitorService.open = !SystemMonitorService.open; }
        function open(): void { SystemMonitorService.open = true; }
        function close(): void { SystemMonitorService.open = false; }
    }

    GlobalShortcut {
        name: "systemMonitorToggle"
        description: "Toggles the system monitor sidebar"
        onPressed: SystemMonitorService.open = !SystemMonitorService.open
    }
}
