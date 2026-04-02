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

    property string barPosition: Settings.data.bar.position || "top"
    property bool barIsVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    readonly property real pillFixedDim: Style.toOdd(capsuleHeight * 0.8)

    implicitWidth: barIsVertical ? capsuleHeight : pillRow.implicitWidth + Style.marginS * 2
    implicitHeight: barIsVertical ? pillRow.implicitHeight + Style.marginS * 2 : capsuleHeight

    // Container capsule
    Rectangle {
        id: container
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: barIsVertical ? capsuleHeight : pillRow.implicitWidth + Style.marginS * 2
        height: barIsVertical ? pillRow.implicitHeight + Style.marginS * 2 : capsuleHeight
        color: Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Behavior on width {
            NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.OutBack
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Style.animationNormal
                easing.type: Easing.OutBack
            }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            Repeater {
                model: root.totalColumns

                Rectangle {
                    id: pill
                    readonly property bool isCurrent: (index + 1) === root.currentColumn

                    width: isCurrent ? pillFixedDim * 1.8 : pillFixedDim
                    height: pillFixedDim
                    radius: Style.radiusM

                    color: {
                        if (pillMouse.containsMouse)
                            return Color.mHover;
                        if (isCurrent)
                            return Color.mPrimary;
                        return Qt.alpha(Color.mSurfaceVariant, 0.3);
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Style.animationNormal
                            easing.type: Easing.OutBack
                        }
                    }
                    Behavior on color {
                        enabled: !Color.isTransitioning
                        ColorAnimation {
                            duration: Style.animationFast
                            easing.type: Easing.InOutQuad
                        }
                    }

                    NText {
                        anchors.centerIn: parent
                        text: (index + 1).toString()
                        family: Settings.data.ui.fontFixed
                        pointSize: pillFixedDim * 0.45
                        applyUiScale: false
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: {
                            if (pillMouse.containsMouse)
                                return Color.mOnHover;
                            if (pill.isCurrent)
                                return Color.mOnPrimary;
                            return Color.mOnSurfaceVariant;
                        }

                        Behavior on color {
                            enabled: !Color.isTransitioning
                            ColorAnimation {
                                duration: Style.animationFast
                                easing.type: Easing.InOutQuad
                            }
                        }
                    }

                    MouseArea {
                        id: pillMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Focus this column by navigating left/right
                            var diff = (index + 1) - root.currentColumn;
                            var action = diff > 0 ? "focus-column-right" : "focus-column-left";
                            for (var i = 0; i < Math.abs(diff); i++) {
                                Quickshell.execDetached(["niri", "msg", "action", action]);
                            }
                        }
                    }
                }
            }
        }
    }

    // Event stream listener
    Process {
        id: eventStream
        command: ["sh", "-c", "niri msg -j event-stream"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                root.parseEvent(data);
            }
        }
    }

    // Refresh on window close
    Process {
        id: refreshWindows
        command: ["sh", "-c", "niri msg -j windows"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.parseWindowList(data);
            }
        }
    }

    function parseEvent(data) {
        try {
            var event = JSON.parse(data);

            if (event.WindowOpenedOrChanged) {
                var win = event.WindowOpenedOrChanged.window;
                if (win.is_focused && win.layout && win.layout.pos_in_scrolling_layout) {
                    root.currentColumn = win.layout.pos_in_scrolling_layout[0];
                    root.totalColumns = win.layout.pos_in_scrolling_layout[1];
                }
            } else if (event.WindowsChanged) {
                parseWindowArray(event.WindowsChanged.windows);
            } else if (event.WindowClosed) {
                refreshWindows.running = true;
            }
        } catch (e) {}
    }

    function parseWindowList(data) {
        try {
            var windows = JSON.parse(data);
            parseWindowArray(windows);
        } catch (e) {}
    }

    function parseWindowArray(windows) {
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
    }

    Component.onCompleted: {
        refreshWindows.running = true;
    }
}
