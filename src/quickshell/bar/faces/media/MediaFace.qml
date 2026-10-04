import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""
    readonly property bool isPlaying: isMediaActive && (player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : MprisController.isPlaying)

    property real colWidth: barWindow ? barWindow.s(isCompact ? 116 : 120) : (isCompact ? 116 : 120)
    property real innerSpacing: barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8)
    property real btnSpacing: barWindow ? barWindow.s(isCompact ? 3 : 4) : (isCompact ? 3 : 4)
    property real sidePadding: barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8)

    property real targetWidth: {
        if (module && !module.moduleActive) return 0;
        let iconW = barWindow ? barWindow.s(isCompact ? 26 : 28) : (isCompact ? 26 : 28);
        let gapInfo = barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10);
        let btnW = (barWindow ? barWindow.s(isCompact ? 28 : 30) : (isCompact ? 28 : 30)) * 3 + btnSpacing * 2;
        let margins = sidePadding * 2;
        return iconW + gapInfo + colWidth + innerSpacing + btnW + margins;
    }

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    function formatTime(sec) {
        sec = Math.floor(sec || 0);
        let m = Math.floor(sec / 60), s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Item {
        id: mediaLayoutContainer
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.sidePadding
        anchors.right: parent.right
        anchors.rightMargin: root.sidePadding
        height: parent.height
        clip: true

        Row {
            id: innerMediaLayout
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.innerSpacing

            MouseArea {
                id: mediaInfoMouse
                width: infoLayout.implicitWidth
                height: mediaLayoutContainer.height
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle music"])

                Row {
                    id: infoLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow ? barWindow.s(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10)
                    transformOrigin: Item.Left

                    scale: mediaInfoMouse.containsMouse ? 1.01 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    Rectangle {
                        id: mediaThumbBox
                        width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                        radius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                        color: root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1
                        border.width: 1
                        border.color: root.isPlaying ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
                        clip: true
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 13 : 14) : (root.isCompact ? 13 : 14)
                            color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                            visible: !isMediaActive || !MprisController.artUrl
                        }

                        Image {
                            id: mediaArtImg
                            anchors.fill: parent
                            source: (isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: mediaArtImg
                            source: mediaArtImg
                            maskEnabled: true
                            maskSource: mediaArtMask
                            visible: isMediaActive && MprisController.artUrl !== "" && mediaArtImg.status === Image.Ready
                        }

                        Item {
                            id: mediaArtMask
                            anchors.fill: parent
                            layer.enabled: true
                            visible: false

                            Rectangle {
                                anchors.fill: parent
                                radius: mediaThumbBox.radius
                                color: "black"
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: ThemeBackend.surface0
                            opacity: 0.15
                            visible: isMediaActive && MprisController.artUrl !== "" && mediaArtImg.status === Image.Ready
                        }
                    }

                    Column {
                        spacing: -2
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.colWidth

                        Item {
                            id: titleClipRect
                            width: parent.width
                            height: titleTextMain.implicitHeight
                            clip: true

                            property int marqueeSpacing: barWindow ? barWindow.s(40) : 40
                            property real scrollProgress: 0.0
                            readonly property real scrollDistance: titleTextMain.implicitWidth + marqueeSpacing
                            readonly property bool canMarquee: root.visible && (!barWindow || barWindow.visible) && (!module || module.moduleActive) && root.isPlaying && (titleTextMain.implicitWidth > width)

                            function resetMarquee() {
                                scrollProgress = 0.0;
                                if (canMarquee) {
                                    titleAnim.restart();
                                } else {
                                    titleAnim.stop();
                                }
                            }

                            onCanMarqueeChanged: resetMarquee()
                            onWidthChanged: resetMarquee()

                            Item {
                                id: marqueeContainer
                                height: parent.height
                                x: titleClipRect.canMarquee ? -Math.round(titleClipRect.scrollProgress * titleClipRect.scrollDistance) : 0

                                Row {
                                    spacing: titleClipRect.marqueeSpacing

                                    Text {
                                        id: titleTextMain
                                        text: isMediaActive ? (player ? player.trackTitle : "") : I18n.t("music.nothing_playing")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                                        color: ThemeBackend.text

                                        onTextChanged: titleClipRect.resetMarquee()
                                    }

                                    Text {
                                        id: titleTextClone
                                        text: titleTextMain.text
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
                                        color: ThemeBackend.text
                                        visible: titleClipRect.canMarquee
                                    }
                                }
                            }

                            SequentialAnimation {
                                id: titleAnim
                                loops: Animation.Infinite
                                running: titleClipRect.canMarquee

                                PauseAnimation { duration: 3000 }

                                NumberAnimation {
                                    target: titleClipRect
                                    property: "scrollProgress"
                                    from: 0.0
                                    to: 1.0
                                    duration: Math.max(1000, titleClipRect.scrollDistance * 30)
                                    easing.type: Easing.Linear
                                }

                                PropertyAction { target: titleClipRect; property: "scrollProgress"; value: 0.0 }
                            }
                        }

                        Text {
                            text: isMediaActive && player ? (root.formatTime(MprisController.livePosition) + " / " + root.formatTime(player.length)) : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                            color: root.isCompact ? ThemeBackend.overlay2 : ThemeBackend.subtext0
                            width: parent.width
                            elide: Text.ElideRight
                            visible: isMediaActive
                        }
                    }
                }
            }

            Row {
                id: buttonRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.btnSpacing

                IconButton {
                    id: prevMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: "󰒮"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoPrevious) player.previous()
                }

                IconButton {
                    id: playMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: root.isPlaying ? "󰏤" : "󰐊"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canTogglePlaying) player.togglePlaying()
                }

                IconButton {
                    id: nextMediaButton
                    height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
                    cornerRadius: barWindow ? barWindow.s(root.isCompact ? 9 : 10) : (root.isCompact ? 9 : 10)
                    buttonIcon: "󰒭"
                    iconFontSize: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                    accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (player && player.canGoNext) player.next()
                }
            }
        }
    }
}
