import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0

    property int currentColumn: 0
    property int totalColumns: 0

    readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : Math.max(label.implicitWidth + Style.marginM * 2, Style.capsuleHeight)
    readonly property real contentHeight: barIsVertical ? Math.round(label.implicitHeight + Style.marginM * 2) : Style.capsuleHeight

    property string barPosition: Settings.data.bar.position || "top"
    property bool barIsVertical: barPosition === "left" || barPosition === "right"

    implicitWidth: contentWidth
    implicitHeight: contentHeight

    Rectangle {
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: root.contentWidth
        height: root.contentHeight
        color: Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        NText {
            id: label
            anchors.centerIn: parent
            text: root.totalColumns > 0 ? root.currentColumn + "/" + root.totalColumns : "-"
            color: Color.mOnSurfaceVariant
            pointSize: Style.barFontSize
        }
    }

    Process {
        id: eventStream
        command: ["sh", "-c", "niri msg -j event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data);

                    if (event.WindowOpenedOrChanged) {
                        var win = event.WindowOpenedOrChanged.window;
                        if (win.is_focused && win.layout && win.layout.pos_in_scrolling_layout) {
                            root.currentColumn = win.layout.pos_in_scrolling_layout[0];
                            root.totalColumns = win.layout.pos_in_scrolling_layout[1];
                        }
                    } else if (event.WindowsChanged) {
                        var windows = event.WindowsChanged.windows;
                        var found = false;
                        for (var i = 0; i < windows.length; i++) {
                            if (windows[i].is_focused && windows[i].layout && windows[i].layout.pos_in_scrolling_layout) {
                                root.currentColumn = windows[i].layout.pos_in_scrolling_layout[0];
                                root.totalColumns = windows[i].layout.pos_in_scrolling_layout[1];
                                found = true;
                                break;
                            }
                        }
                        if (!found) {
                            root.currentColumn = 0;
                            root.totalColumns = 0;
                        }
                    } else if (event.WindowClosed) {
                        refreshWindows.running = true;
                    }
                } catch (e) {}
            }
        }
    }

    // Refresh after window close since the event doesn't include layout info
    Process {
        id: refreshWindows
        command: ["sh", "-c", "niri msg -j windows"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    var windows = JSON.parse(data);
                    var found = false;
                    for (var i = 0; i < windows.length; i++) {
                        if (windows[i].is_focused && windows[i].layout && windows[i].layout.pos_in_scrolling_layout) {
                            root.currentColumn = windows[i].layout.pos_in_scrolling_layout[0];
                            root.totalColumns = windows[i].layout.pos_in_scrolling_layout[1];
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        root.currentColumn = 0;
                        root.totalColumns = 0;
                    }
                } catch (e) {}
            }
        }
    }

    // Initial fetch
    Component.onCompleted: {
        refreshWindows.running = true;
    }
}
