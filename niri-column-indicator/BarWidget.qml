import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI
import qs.Services.Compositor

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
    property int focusedWorkspaceIdx: 0

    property string barPosition: Settings.data.bar.position || "top"
    property bool barIsVertical: barPosition === "left" || barPosition === "right"
    readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screen?.name)
    readonly property real pillDim: Style.toOdd(capsuleHeight * 0.8)

    implicitWidth: barIsVertical ? capsuleHeight : contentRow.implicitWidth + Style.marginS * 2
    implicitHeight: barIsVertical ? contentRow.implicitHeight + Style.marginS * 2 : capsuleHeight

    // Listen to CompositorService signals to trigger refresh
    Connections {
        target: CompositorService
        function onWorkspacesChanged() {
            root.scheduleRefresh();
        }
        function onWindowListChanged() {
            root.scheduleRefresh();
        }
        function onActiveWindowChanged() {
            root.scheduleRefresh();
        }
    }

    function scheduleRefresh() {
        refreshDebounce.restart();
    }

    Timer {
        id: refreshDebounce
        interval: 50
        repeat: false
        onTriggered: {
            updateWorkspaceFromCompositor();
            fetchProc.running = true;
        }
    }

    function updateWorkspaceFromCompositor() {
        for (var i = 0; i < CompositorService.workspaces.count; i++) {
            var ws = CompositorService.workspaces.get(i);
            if (ws.isFocused) {
                root.focusedWorkspaceIdx = ws.idx;
                break;
            }
        }
    }

    // Fetch column data from niri
    Process {
        id: fetchProc
        command: ["niri", "msg", "-j", "windows"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                try {
                    var windows = JSON.parse(data);
                    var focusedCol = 0;
                    var focusedWsId = -1;
                    var maxCol = 0;

                    for (var i = 0; i < windows.length; i++) {
                        var win = windows[i];
                        if (win.is_focused && !win.is_floating && win.layout && win.layout.pos_in_scrolling_layout) {
                            focusedCol = win.layout.pos_in_scrolling_layout[0];
                            focusedWsId = win.workspace_id;
                        }
                    }

                    if (focusedWsId >= 0) {
                        for (var j = 0; j < windows.length; j++) {
                            if (windows[j].workspace_id === focusedWsId &&
                                !windows[j].is_floating &&
                                windows[j].layout && windows[j].layout.pos_in_scrolling_layout) {
                                var col = windows[j].layout.pos_in_scrolling_layout[0];
                                if (col > maxCol) maxCol = col;
                            }
                        }
                    }

                    root.currentColumn = focusedCol;
                    root.totalColumns = maxCol;
                } catch (e) {}
            }
        }
    }

    Rectangle {
        id: container
        x: Style.pixelAlignCenter(parent.width, width)
        y: Style.pixelAlignCenter(parent.height, height)
        width: barIsVertical ? capsuleHeight : contentRow.implicitWidth + Style.marginS * 2
        height: barIsVertical ? contentRow.implicitHeight + Style.marginS * 2 : capsuleHeight
        color: Style.capsuleColor
        radius: Style.radiusM
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth

        Behavior on width {
            NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutBack }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            // Workspace pill
            Rectangle {
                width: pillDim * 1.4
                height: pillDim
                radius: Style.radiusM
                color: Color.mTertiary

                NText {
                    anchors.centerIn: parent
                    text: root.focusedWorkspaceIdx > 0 ? root.focusedWorkspaceIdx.toString() : "-"
                    family: Settings.data.ui.fontFixed
                    pointSize: pillDim * 0.45
                    applyUiScale: false
                    font.weight: Font.Bold
                    color: Color.mOnTertiary
                }
            }

            // Separator
            Rectangle {
                width: 1
                height: pillDim * 0.6
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.alpha(Color.mOnSurfaceVariant, 0.3)
                visible: root.totalColumns > 0
            }

            // Column pills
            Repeater {
                model: root.totalColumns

                Rectangle {
                    id: colPill
                    readonly property bool isCurrent: (index + 1) === root.currentColumn

                    width: isCurrent ? pillDim * 1.6 : pillDim
                    height: pillDim
                    radius: Style.radiusS

                    color: {
                        if (colMouse.containsMouse)
                            return Color.mHover;
                        if (isCurrent)
                            return Color.mPrimary;
                        return Qt.alpha(Color.mSurfaceVariant, 0.6);
                    }

                    Behavior on width {
                        NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        enabled: !Color.isTransitioning
                        ColorAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
                    }

                    NText {
                        anchors.centerIn: parent
                        text: (index + 1).toString()
                        family: Settings.data.ui.fontFixed
                        pointSize: pillDim * 0.38
                        applyUiScale: false
                        font.weight: Font.Bold
                        opacity: 1.0
                        color: {
                            if (colMouse.containsMouse)
                                return Color.mOnHover;
                            if (colPill.isCurrent)
                                return Color.mOnPrimary;
                            return Color.mOnSurfaceVariant;
                        }

                        Behavior on opacity {
                            NumberAnimation { duration: Style.animationFast; easing.type: Easing.InOutQuad }
                        }
                    }

                    MouseArea {
                        id: colMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
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

    Component.onCompleted: {
        updateWorkspaceFromCompositor();
        fetchProc.running = true;
    }
}
