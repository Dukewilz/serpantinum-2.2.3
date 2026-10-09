import QtQuick
import QtQuick.Layouts
import "../../../../reusables"
import "../../../../"

Item {
    id: sidePacmanFaceRoot
    property var widget: null

    property real slotSize: widget ? widget.s(widget.isCompact ? 16 : 18) : 18
    property real slotSpacing: widget ? widget.s(widget.isCompact ? 7 : 8) : 8

    implicitWidth: pelletsCol.implicitWidth
    implicitHeight: pelletsCol.implicitHeight

    property int activeIdx: widget ? widget.activeIndex : 0
    property int prevIdx: 0
    property real pacmanAngle: 90

    property real stepSize: slotSize + slotSpacing
    property real targetPacmanY: activeIdx >= 0 ? (pelletsCol.y + activeIdx * stepSize) : 0
    property real currentPacmanY: targetPacmanY

    Behavior on currentPacmanY {
        NumberAnimation { duration: 320; easing.type: Easing.OutQuint }
    }

    property real mouthAngle: 0.25

    SequentialAnimation {
        id: chompAnim
        loops: 2
        NumberAnimation {
            target: sidePacmanFaceRoot
            property: "mouthAngle"
            to: 0.02
            duration: 80
            easing.type: Easing.InOutQuad
        }
        NumberAnimation {
            target: sidePacmanFaceRoot
            property: "mouthAngle"
            to: 0.25
            duration: 80
            easing.type: Easing.InOutQuad
        }
    }

    onMouthAngleChanged: pacmanCanvas.requestPaint()

    onActiveIdxChanged: {
        if (activeIdx < prevIdx) {
            pacmanAngle = 270;
        } else if (activeIdx > prevIdx) {
            pacmanAngle = 90;
        }
        prevIdx = activeIdx;
        chompAnim.restart();
    }

    Column {
        id: pelletsCol
        z: 1
        anchors.centerIn: parent
        spacing: sidePacmanFaceRoot.slotSpacing

        Repeater {
            model: widget ? widget.workspaceCount : 0

            delegate: Item {
                id: pelletSlot
                required property int index

                width: sidePacmanFaceRoot.slotSize
                height: sidePacmanFaceRoot.slotSize

                property bool isOccupied: widget ? widget.isOccupied(index) : false
                property bool isActive: widget ? (index === widget.activeIndex) : false
                property bool isHovered: pelletMouse.containsMouse
                property bool isPowerPellet: index % 2 === 1
                property bool initAnimTrigger: false

                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: pelletSlot.isPowerPellet
                        ? (pelletSlot.isOccupied
                            ? (widget ? widget.s(widget.isCompact ? 9 : 11) : 11)
                            : (widget ? widget.s(widget.isCompact ? 7 : 8) : 8))
                        : (pelletSlot.isOccupied
                            ? (widget ? widget.s(widget.isCompact ? 5 : 6) : 6)
                            : (widget ? widget.s(widget.isCompact ? 4 : 5) : 5))
                    height: width
                    radius: width / 2
                    color: pelletSlot.isOccupied
                        ? ThemeBackend.surface2
                        : ((widget && widget.isCompact) ? ThemeBackend.surface1 : ThemeBackend.surface0)
                    opacity: pelletSlot.isActive ? 0.0 : (pelletSlot.isHovered ? 1.0 : 0.85)

                    scale: pelletMouse.pressed ? 0.88 : (pelletSlot.isHovered ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                opacity: initAnimTrigger ? 1.0 : 0.0
                transform: Translate {
                    x: pelletSlot.initAnimTrigger ? 0 : (widget ? widget.s(15) : 15)
                    Behavior on x { NumberAnimation { duration: 650; easing.type: Easing.OutQuint } }
                }

                Component.onCompleted: {
                    if (widget && widget.barWindow && !widget.barWindow.startupCascadeFinished) {
                        animTimer.interval = index * 50 + 100;
                        if (widget.moduleActive) animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }

                Timer {
                    id: animTimer
                    running: false
                    repeat: false
                    onTriggered: pelletSlot.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                MouseArea {
                    id: pelletMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (widget) widget.focusWorkspace(pelletSlot.index);
                    }
                }
            }
        }
    }

    Item {
        id: pacmanActor
        z: 3
        x: pelletsCol.x + (pelletsCol.width - width) / 2
        y: sidePacmanFaceRoot.currentPacmanY
        width: sidePacmanFaceRoot.slotSize
        height: sidePacmanFaceRoot.slotSize
        visible: widget && widget.workspaceCount > 0 && widget.activeIndex >= 0
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 180 } }

        rotation: sidePacmanFaceRoot.pacmanAngle

        Canvas {
            id: pacmanCanvas
            anchors.fill: parent

            Connections {
                target: ThemeBackend
                function onMauveChanged() { pacmanCanvas.requestPaint(); }
                function onCrustChanged() { pacmanCanvas.requestPaint(); }
            }

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: requestPaint()

            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let r = width / 2;
                let m = sidePacmanFaceRoot.mouthAngle * Math.PI;

                ctx.beginPath();
                ctx.moveTo(r, r);
                ctx.arc(r, r, r - 0.5, m, (2 * Math.PI) - m, false);
                ctx.closePath();
                ctx.fillStyle = (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.mauve, 1.05) : ThemeBackend.mauve;
                ctx.fill();

                let eyeR = Math.max(1.5, r * 0.15);
                let eyeX = r + r * 0.1;
                let eyeY = r - r * 0.45;

                ctx.beginPath();
                ctx.arc(eyeX, eyeY, eyeR, 0, 2 * Math.PI, false);
                ctx.fillStyle = ThemeBackend.crust;
                ctx.fill();
            }
        }
    }
}
