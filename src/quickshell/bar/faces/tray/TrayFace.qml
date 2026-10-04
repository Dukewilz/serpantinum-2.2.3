import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false
    readonly property bool isRightAligned: module ? module.isRightAligned : true

    property bool showLayout: false

    readonly property real iconSize: barWindow ? barWindow.s(isCompact ? 15 : 16) : (isCompact ? 15 : 16)
    readonly property real itemSpacing: barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10)
    readonly property real iconPadding: barWindow ? barWindow.s(isCompact ? 10 : 12) : (isCompact ? 10 : 12)
    readonly property real totalPadding: iconPadding * 2
    readonly property int itemCount: ((!module || module.moduleActive) && trayRepeater.count > 0) ? trayRepeater.count : 0

    property real targetWidth: itemCount > 0 ? (itemCount * iconSize + (itemCount - 1) * itemSpacing + totalPadding) : 0
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Component.onDestruction: {
        TrayMenuController.hide();
    }

    onVisibleChanged: {
        if (!visible) {
            TrayMenuController.hide();
        }
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                TrayMenuController.hide();
            }
        }
    }

    Connections {
        target: barWindow || null
        function onPositionChangingChanged() {
            if (barWindow && barWindow.positionChanging) {
                TrayMenuController.hide();
            }
        }
        function onBarPositionChanged() {
            TrayMenuController.hide();
        }
        function onIsRevealedChanged() {
            if (barWindow && !barWindow.isRevealed && !TrayMenuController.menuHovered) {
                TrayMenuController.hide();
            }
        }
    }

    Timer {
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x {
            enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging && (!module || !module.suppressAnimation)
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Row {
        id: trayLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: root.isRightAligned ? undefined : parent.left
        anchors.leftMargin: root.isRightAligned ? 0 : root.iconPadding
        anchors.right: root.isRightAligned ? parent.right : undefined
        anchors.rightMargin: root.isRightAligned ? root.iconPadding : 0
        spacing: root.itemSpacing

        Repeater {
            id: trayRepeater
            model: (!module || module.moduleActive) ? SystemTray.items : null

            onCountChanged: {
                if (count === 0) {
                    TrayMenuController.hide();
                }
            }

            delegate: Image {
                id: trayIcon
                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit

                sourceSize: Qt.size(root.iconSize, root.iconSize)
                width: root.iconSize
                height: root.iconSize
                anchors.verticalCenter: parent.verticalCenter

                property bool isHovered: trayMouse.containsMouse
                property bool initAnimTrigger: false
                opacity: initAnimTrigger ? (isHovered ? 1.0 : (root.isCompact ? 0.9 : 0.8)) : 0.0
                scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                Component.onCompleted: {
                    if (barWindow && !barWindow.startupCascadeFinished) {
                        trayAnimTimer.interval = index * 45 + 180
                        if (!module || module.moduleActive) trayAnimTimer.start()
                    } else {
                        initAnimTrigger = true
                    }
                }

                Component.onDestruction: {
                    if (trayMouse.containsMouse) {
                        TrayMenuController.itemExited();
                    }
                    let idStr = (modelData && modelData.id !== undefined && modelData.id !== null && String(modelData.id).length > 0) ? String(modelData.id) : String(index);
                    if (TrayMenuController.activeItemId === idStr) {
                        TrayMenuController.hide();
                    }
                }

                Timer {
                    id: trayAnimTimer
                    running: false
                    repeat: false
                    onTriggered: trayIcon.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                function openMenu(action) {
                    TrayMenuController.cancelHide();
                    let pt = trayIcon.mapToItem(null, 0, 0);
                    let scr = (barWindow && barWindow.screen) ? barWindow.screen : null;
                    let globX = pt.x + (width / 2);
                    let globY = root.isBottomBar ? pt.y : (pt.y + height);
                    let idStr = (modelData && modelData.id !== undefined && modelData.id !== null && String(modelData.id).length > 0) ? String(modelData.id) : String(index);

                    if (action === "toggle") {
                        TrayMenuController.toggle(idStr, scr, globX, globY, false, root.isBottomBar, false);
                    } else {
                        TrayMenuController.itemEntered(idStr, scr, globX, globY, false, root.isBottomBar, false);
                    }
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    anchors.margins: -(barWindow ? barWindow.s(4) : 4)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onEntered: {
                        trayIcon.openMenu("show");
                    }

                    onExited: {
                        TrayMenuController.itemExited();
                    }

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            if (modelData.isMenuOnly || modelData.onlyMenu) {
                                trayIcon.openMenu("toggle");
                            } else if (typeof modelData.activate === "function") {
                                modelData.activate();
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            if (typeof modelData.secondaryActivate === "function") {
                                modelData.secondaryActivate();
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.menu) {
                                trayIcon.openMenu("toggle");
                            } else if (typeof modelData.contextMenu === "function") {
                                modelData.contextMenu(mouse.x, mouse.y);
                            } else if (typeof modelData.activate === "function") {
                                modelData.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
