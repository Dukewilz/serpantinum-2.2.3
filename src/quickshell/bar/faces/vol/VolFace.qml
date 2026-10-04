import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    property bool isMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false
    property string volPercent: sysVolume + "%"
    property string volIcon: isMuted || sysVolume === 0 ? "󰖁" : (sysVolume > 50 ? "󰕾" : "󰖀")
    property bool sysMuted: isMuted

    property bool isDraggingVol: false
    property bool isSoundActive: !isMuted && sysVolume > 0
    property bool showLayout: false
    property alias volPill: volPill

    property real targetWidth: ((!module || module.moduleActive) && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    property bool isFaceVisible: showLayout && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    Timer {
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: root.showLayout = true
    }

    transform: Translate {
        x: root.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)

        ClickButton {
            id: volPill
            property bool initAnimTrigger: false
            property bool isActive: root.isSoundActive

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(root.isCompact ? 96 : 100) : (root.isCompact ? 96 : 100)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(root.isCompact ? 10 : 12) : (root.isCompact ? 10 : 12)
            buttonIcon: root.volIcon
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            buttonText: root.volPercent
            textFontSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            accentColor: isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.12) : ThemeBackend.surface1)
            textColor: isActive ? ThemeBackend.base : (root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0)

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            Timer { running: (!module || module.moduleActive) && root.showLayout && !volPill.initAnimTrigger; interval: 250; onTriggered: volPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: volPill.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle volume"])
            onRightClicked: if (Audio.defaultSink) Audio.toggleMute(Audio.defaultSink)

            property real wheelAccumulator: 0
            Timer {
                id: volWheelTimer
                interval: 200
                onTriggered: volPill.wheelAccumulator = 0
            }

            onWheel: wheel => {
                volWheelTimer.restart()
                volPill.wheelAccumulator += wheel.angleDelta.y
                const threshold = 120
                if (Math.abs(volPill.wheelAccumulator) >= threshold) {
                    let steps = Math.trunc(volPill.wheelAccumulator / threshold)
                    volPill.wheelAccumulator = volPill.wheelAccumulator % threshold
                    if (steps !== 0 && Audio.defaultSink) {
                        let newVol = Math.max(0, Math.min(100, root.sysVolume + (steps * 5)))
                        Audio.setVolume(Audio.defaultSink, newVol)
                    }
                }
            }
        }
    }
}
