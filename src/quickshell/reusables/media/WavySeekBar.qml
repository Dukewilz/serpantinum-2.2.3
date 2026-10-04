import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import "../"
import "../../"

Item {
    id: bar
    implicitWidth: 200
    implicitHeight: 32

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0
    property bool playing: false
    property bool active: bar.visible && (!Window.window || Window.window.visible)

    property color waveColor: ThemeBackend.mauve || "#cba6f7"
    Behavior on waveColor { ColorAnimation { duration: 600 } }
    property color primaryColor: waveColor
    Behavior on primaryColor { ColorAnimation { duration: 600 } }
    property color secondaryColor: ThemeBackend.lavender || "#b4befe"
    Behavior on secondaryColor { ColorAnimation { duration: 600 } }
    property color tertiaryColor: ThemeBackend.blue || "#89b4fa"
    Behavior on tertiaryColor { ColorAnimation { duration: 600 } }

    property real trackAlpha: 0.28
    property color handleHoverColor: Qt.lighter(waveColor, 1.15)

    function s(val) {
        return (typeof Scaler !== "undefined") ? Scaler.s(val) : val;
    }

    property real handleSize: height < 30 ? Math.max(8, Math.min(14, height * 0.75)) : bar.s(17)
    property real strokeWidth: height < 30 ? Math.max(2.5, handleSize * 0.35) : bar.s(9)
    property real amplitude: height < 30 ? Math.max(3, height * 0.35) : bar.s(14)
    property int cycleMs: 3000
    property real restingLevel: 0.0

    readonly property real cy: height - handleSize * (height < 30 ? 0.65 : 0.7)
    property real pad: handleSize / 2
    property real mouseAreaHeight: height < 30 ? height : Math.min(height, Math.max(handleSize * 1.4, bar.s(22)))
    property bool isDragging: mouseArea.pressed
    signal moved(real val)

    property real ampFactor: playing ? 1.0 : restingLevel
    Behavior on ampFactor {
        NumberAnimation { duration: 600; easing.type: Easing.OutQuad }
    }

    readonly property real liveAmp: ampFactor

    property real progressFraction: (to > from) ? Math.max(0.0, Math.min(1.0, (value - from) / (to - from))) : 0.0
    property real shownFraction: progressFraction
    Behavior on shownFraction {
        enabled: !bar.isDragging
        NumberAnimation { duration: 250; easing.type: Easing.Linear }
    }

    readonly property real progressX: pad + shownFraction * (width - 2 * pad)

    property real phase: 0

    property real step: height < 30 ? 2.0 : Math.max(2, bar.s(2.5))
    property real startTaperMin: height < 30 ? 12 : bar.s(24)
    property real startTaperMax: height < 30 ? 32 : bar.s(64)

    property string trackColorStr: ""
    property string fullColorStr: ""
    property var layerColorStrs: []
    property var gridTables: []
    property var cachedGradients: []

    property real scaleFactor: height < 30 ? (height / 35) : 1.0
    readonly property real trackWidth: Math.max(10, bar.width - 2 * bar.pad)
    readonly property real baseLen: (trackWidth > 0 ? (trackWidth / 3.0) : bar.s(65))

    property var layers: [
        { color: bar.primaryColor, amp: 0.65, alpha: 0.50, taper: bar.s(130) * bar.scaleFactor, comps: [
            { len: bar.baseLen * 1.75, mult: 1.0, off: 0.00, w: 1.0 } ] },
        { color: bar.primaryColor, amp: 0.71, alpha: 0.90, taper: bar.s(105) * bar.scaleFactor, comps: [
            { len: bar.baseLen * 1.05, mult: 2.2, off: 1.80, w: 1.0 } ] }
    ]

    function rgbaCol(col, a) {
        if (!col) return "rgba(0,0,0," + a + ")";
        return "rgba(" + Math.round(col.r * 255) + "," + Math.round(col.g * 255) + "," + Math.round(col.b * 255) + "," + a + ")";
    }

    function easeQuintic(t) {
        t = Math.max(0, Math.min(1, t));
        return t * t * t * (t * (t * 6 - 15) + 10);
    }

    function updateColors() {
        trackColorStr = rgbaCol(bar.waveColor, bar.trackAlpha);
        fullColorStr = rgbaCol(bar.waveColor, 1.0);
        var arr = [];
        var L = bar.layers;
        if (L) {
            for (var i = 0; i < L.length; i++) {
                var curCol = L[i].color || bar.primaryColor;
                var a1 = L[i].alpha;
                var a0 = a1 >= 1.0 ? 1.0 : (a1 * 0.55);
                arr.push({
                    c0: rgbaCol(curCol, a0),
                    c1: rgbaCol(curCol, a1)
                });
            }
        }
        layerColorStrs = arr;
        cachedGradients = [];
    }

    function rebuildGridTables() {
        var L = bar.layers;
        if (!L || L.length === 0 || bar.width <= 0) return;
        var maxSteps = Math.ceil(bar.width / bar.step) + 4;
        var tables = [];
        for (var li = 0; li < L.length; li++) {
            var comps = L[li].comps;
            var layerSins = [];
            var layerCoss = [];
            var layerSwellSins = [];
            var layerSwellCoss = [];
            for (var k = 0; k < comps.length; k++) {
                var p = comps[k];
                var kFreq = (2 * Math.PI) / p.len;
                var swellFreq = kFreq / 6.0;
                var swellOff = (li === 0) ? 0.0 : Math.PI;
                var sins = new Float64Array(maxSteps);
                var coss = new Float64Array(maxSteps);
                var swellSins = new Float64Array(maxSteps);
                var swellCoss = new Float64Array(maxSteps);
                for (var i = 0; i < maxSteps; i++) {
                    var x = bar.pad + i * bar.step;
                    var angle = kFreq * x + p.off;
                    sins[i] = Math.sin(angle);
                    coss[i] = Math.cos(angle);
                    var swellAngle = swellFreq * x + swellOff;
                    swellSins[i] = Math.sin(swellAngle);
                    swellCoss[i] = Math.cos(swellAngle);
                }
                layerSins.push(sins);
                layerCoss.push(coss);
                layerSwellSins.push(swellSins);
                layerSwellCoss.push(swellCoss);
            }
            tables.push({
                sins: layerSins,
                coss: layerCoss,
                swellSins: layerSwellSins,
                swellCoss: layerSwellCoss,
                maxSteps: maxSteps
            });
        }
        bar.gridTables = tables;
    }

    function hillFromGrid(table, comps, i, cosBetas, sinBetas, cosSwellBetas, sinSwellBetas) {
        var n = 0;
        var mod = 1.0;
        for (var k = 0; k < comps.length; k++) {
            n += comps[k].w * (table.sins[k][i] * cosBetas[k] - table.coss[k][i] * sinBetas[k]);
            var swellVal = table.swellSins[k][i] * cosSwellBetas[k] - table.swellCoss[k][i] * sinSwellBetas[k];
            mod = 0.80 + 0.20 * swellVal;
        }
        var baseH = 0.5 * (1 + Math.max(-1.0, Math.min(1.0, n)));
        return baseH * mod;
    }

    function hillDirect(x, comps, phaseVal, li) {
        var n = 0;
        var mod = 1.0;
        var swellOff = (li === 0) ? 0.0 : Math.PI;
        for (var k = 0; k < comps.length; k++) {
            var p = comps[k];
            n += p.w * Math.sin((2 * Math.PI / p.len) * x - phaseVal * p.mult + p.off);
            var swellFreq = (2 * Math.PI) / (p.len * 6.0);
            var swellVal = Math.sin(swellFreq * x - phaseVal * p.mult * 0.5 + swellOff);
            mod = 0.80 + 0.20 * swellVal;
        }
        var baseH = 0.5 * (1 + Math.max(-1.0, Math.min(1.0, n)));
        return baseH * mod;
    }

    Component.onCompleted: {
        updateColors();
        rebuildGridTables();
    }

    onActiveChanged: {
        if (bar.active) {
            bar.updateColors();
            bar.rebuildGridTables();
            cv.requestPaint();
        }
    }

    onLiveAmpChanged: { if (bar.active) cv.requestPaint(); }
    onWaveColorChanged: { updateColors(); if (bar.active) cv.requestPaint(); }
    onPrimaryColorChanged: { updateColors(); if (bar.active) cv.requestPaint(); }
    onSecondaryColorChanged: { if (bar.active) cv.requestPaint(); }
    onTertiaryColorChanged: { if (bar.active) cv.requestPaint(); }
    onShownFractionChanged: { if (bar.active) cv.requestPaint(); }
    onWidthChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onPadChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onStepChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onBaseLenChanged: { rebuildGridTables(); if (bar.active) cv.requestPaint(); }
    onLayersChanged: { updateColors(); rebuildGridTables(); if (bar.active) cv.requestPaint(); }

    Timer {
        id: waveTimer
        interval: 16
        repeat: true
        running: bar.active && (bar.playing || bar.ampFactor > 0.001)
        property real lastTime: 0

        onRunningChanged: {
            if (!running) lastTime = 0;
        }

        onTriggered: {
            var now = Date.now();
            if (lastTime > 0) {
                var dt = now - lastTime;
                if (dt > 0 && dt < 1000) {
                    bar.phase += (dt / bar.cycleMs) * Math.PI * 2;
                }
            }
            lastTime = now;
            cv.requestPaint();
        }
    }

    Canvas {
        id: cv
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject

        opacity: (bar.isDragging || mouseArea.containsMouse) ? 1.0 : (bar.playing ? 1.0 : 0.55)
        Behavior on opacity {
            NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
        }

        onPaint: {
            if (!bar.active) return;

            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cy = bar.cy;
            var pad = bar.pad;
            var right = width - pad;
            var endX = Math.max(pad, bar.progressX);
            var strokeW = bar.strokeWidth;
            var top = cy - strokeW / 2;
            var step = bar.step;
            var startTaper = bar.startTaperMax;
            var currentPhase = bar.phase;
            var barAmp = bar.amplitude;
            var currentLiveAmp = bar.liveAmp;
            var L = bar.layers;

            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.lineWidth = strokeW;
            ctx.globalAlpha = 1.0;

            ctx.strokeStyle = bar.trackColorStr || bar.rgbaCol(bar.waveColor, bar.trackAlpha);
            ctx.beginPath();
            ctx.moveTo(endX, cy);
            ctx.lineTo(right, cy);
            ctx.stroke();

            if (endX > pad + 1 && L) {
                var tables = bar.gridTables;
                var hasTables = tables && tables.length === L.length;
                var gradients = bar.cachedGradients;
                var colorStrs = bar.layerColorStrs;

                for (var li = 0; li < L.length; li++) {
                    var ly = L[li];
                    var A = barAmp * ly.amp * currentLiveAmp;
                    if (A < 0.3) continue;

                    var endTaperLen = ly.taper;

                    var g = (gradients && gradients[li] && gradients[li]._top === top && gradients[li]._a === A)
                        ? gradients[li]
                        : null;

                    if (!g) {
                        g = ctx.createLinearGradient(0, top - A, 0, top);
                        var a1 = ly.alpha;
                        var a0 = a1 >= 1.0 ? 1.0 : (a1 * 0.55);
                        var colPair = (colorStrs && colorStrs[li]) ? colorStrs[li] : {
                            c0: bar.rgbaCol(ly.color || bar.primaryColor, a0),
                            c1: bar.rgbaCol(ly.color || bar.primaryColor, a1)
                        };
                        g.addColorStop(0.0, colPair.c0);
                        g.addColorStop(1.0, colPair.c1);
                        g._top = top;
                        g._a = A;
                        if (!gradients) gradients = [];
                        gradients[li] = g;
                    }

                    var comps = ly.comps;
                    var numComps = comps.length;
                    var cosBetas = new Float64Array(numComps);
                    var sinBetas = new Float64Array(numComps);
                    var cosSwellBetas = new Float64Array(numComps);
                    var sinSwellBetas = new Float64Array(numComps);
                    for (var k = 0; k < numComps; k++) {
                        var beta = comps[k].mult * currentPhase;
                        cosBetas[k] = Math.cos(beta);
                        sinBetas[k] = Math.sin(beta);
                        var swellBeta = comps[k].mult * 0.5 * currentPhase;
                        cosSwellBetas[k] = Math.cos(swellBeta);
                        sinSwellBetas[k] = Math.sin(swellBeta);
                    }

                    var table = hasTables ? tables[li] : null;
                    var canUseGrid = table && table.sins && table.sins.length === numComps && table.swellSins && table.swellSins.length === numComps;

                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.moveTo(pad, cy);

                    var gridIdx = 0;
                    for (var x = pad; ; x += step, gridIdx++) {
                        var curX = Math.min(x, endX);
                        var env = bar.easeQuintic((curX - pad) / startTaper) * bar.easeQuintic((endX - curX) / endTaperLen);
                        var h = (canUseGrid && curX === x && gridIdx < table.maxSteps)
                            ? bar.hillFromGrid(table, comps, gridIdx, cosBetas, sinBetas, cosSwellBetas, sinSwellBetas)
                            : bar.hillDirect(curX, comps, currentPhase, li);
                        var yPos = top - h * A * env;
                        ctx.lineTo(curX, yPos);
                        if (curX >= endX) break;
                    }
                    ctx.lineTo(endX, top);
                    ctx.lineTo(endX, cy);
                    ctx.closePath();
                    ctx.fill();
                }
                bar.cachedGradients = gradients;
            }

            ctx.strokeStyle = bar.fullColorStr || bar.rgbaCol(bar.waveColor, 1.0);
            ctx.beginPath();
            ctx.moveTo(pad, cy);
            ctx.lineTo(endX, cy);
            ctx.stroke();
        }
    }

    Rectangle {
        id: handle
        x: Math.max(0, Math.min(bar.width - width, bar.progressX - width / 2))
        y: bar.cy - height / 2
        width: bar.handleSize
        height: bar.handleSize
        radius: width / 2
        color: bar.isDragging ? bar.handleHoverColor : (mouseArea.containsMouse ? bar.handleHoverColor : bar.waveColor)
        opacity: 1.0
        scale: bar.isDragging ? 1.25 : (mouseArea.containsMouse ? 1.15 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }
        Behavior on color {
            ColorAnimation { duration: 150 }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: bar.s(1.0)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.45
        }
    }

    MouseArea {
        id: mouseArea
        anchors.left: parent.left
        anchors.right: parent.right
        height: bar.mouseAreaHeight
        y: Math.max(0, Math.min(bar.height - height, Math.round(bar.cy - height / 2)))
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updatePos(mx) {
            var avail = bar.width - 2 * bar.pad;
            if (avail <= 0) return;
            var frac = Math.max(0.0, Math.min(1.0, (mx - bar.pad) / avail));
            var newVal = bar.from + frac * (bar.to - bar.from);
            bar.value = newVal;
            bar.moved(newVal);
        }

        onPressed: mouse => updatePos(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) updatePos(mouse.x);
        }
    }
}
