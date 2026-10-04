import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root

    property var module: null
    property var widget: root

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool moduleActive: module ? module.moduleActive : true

    property bool isNiri: false
    property bool isSway: false
    property int niriActiveIndex: 0
    property var niriOccupiedMap: ({})
    property int swayActiveIndex: 0
    property var swayOccupiedMap: ({})

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.workspacesStyle) return Config.rawSettings.bar.workspacesStyle;
            if (Config.rawSettings.bar.workspaces && Config.rawSettings.bar.workspaces.style) return Config.rawSettings.bar.workspaces.style;
        }
        return "pills";
    }

    property int baseWorkspaceCount: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }

    property int workspaceCount: Math.max(2, (activeIndex >= baseWorkspaceCount) ? (activeIndex + 1) : baseWorkspaceCount)

    property bool hideEmptyWorkspaces: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.hideEmptyWorkspaces !== undefined)
                return Boolean(Config.rawSettings.bar.hideEmptyWorkspaces);
        }
        return false;
    }

    ListModel {
        id: workspaceListModel
    }

    function syncModel() {
        let target = workspaceCount;
        while (workspaceListModel.count < target) {
            workspaceListModel.append({ "modelData": workspaceListModel.count });
        }
        while (workspaceListModel.count > target) {
            workspaceListModel.remove(workspaceListModel.count - 1);
        }
    }

    onWorkspaceCountChanged: syncModel()

    function findRepeater(obj) {
        if (!obj) return null;
        if (obj.model !== undefined && obj.count !== undefined && typeof obj.itemAt === "function") {
            return obj;
        }
        if (obj.children) {
            for (let i = 0; i < obj.children.length; i++) {
                let res = findRepeater(obj.children[i]);
                if (res) return res;
            }
        }
        if (obj.data) {
            for (let j = 0; j < obj.data.length; j++) {
                let res = findRepeater(obj.data[j]);
                if (res) return res;
            }
        }
        return null;
    }

    function attachModel() {
        if (faceLoader.item) {
            faceLoader.item.widget = root;
            let rep = findRepeater(faceLoader.item);
            if (rep && rep.model !== workspaceListModel) {
                rep.model = workspaceListModel;
            }
        }
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function wsForId(id) {
        if (isNiri || isSway) return null;
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isOccupied(index) {
        if (isNiri) return !!niriOccupiedMap[index];
        if (isSway) return !!swayOccupiedMap[index];
        let ws = wsForId(index + 1);
        return ws !== null && ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0;
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces) return true;
        return index === activeIndex || isOccupied(index);
    }

    function focusWorkspace(index) {
        let wsId = index + 1;
        if (isNiri) {
            niriActiveIndex = index;
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", wsId.toString()]);
        } else if (isSway) {
            swayActiveIndex = index;
            Quickshell.execDetached(["swaymsg", "workspace", "number", wsId.toString()]);
        } else {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
        }
    }

    property int activeIndex: {
        let idx = -1;
        if (isNiri) {
            idx = niriActiveIndex;
        } else if (isSway) {
            idx = swayActiveIndex;
        } else {
            const fw = Hyprland.focusedWorkspace;
            if (!fw) return -1;
            idx = fw.id - 1;
        }
        return idx >= 0 ? idx : -1;
    }

    Component.onCompleted: {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isNiri = de.indexOf("niri") !== -1;
        root.isSway = de.indexOf("sway") !== -1;
        if (root.isNiri && root.moduleActive) {
            niriPoller.running = true;
            niriEventStream.running = true;
        }
        if (root.isSway && root.moduleActive) {
            swayPoller.running = true;
        }
        syncModel();
    }

    onModuleActiveChanged: {
        if (!moduleActive) {
            if (isNiri) {
                niriPoller.running = false;
                niriDebounceTimer.stop();
                niriRestartTimer.stop();
                niriEventStream.running = false;
            }
            if (isSway) {
                swayPoller.running = false;
                swayWaiter.running = false;
            }
        } else {
            if (isNiri) {
                niriPoller.running = false;
                niriPoller.running = true;
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
            if (isSway) {
                swayPoller.running = false;
                swayPoller.running = true;
            }
        }
    }

    Timer {
        id: niriDebounceTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (root.moduleActive && root.isNiri) {
                niriPoller.running = false;
                niriPoller.running = true;
            }
        }
    }

    Timer {
        id: niriRestartTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.moduleActive && root.isNiri) {
                niriEventStream.running = false;
                niriEventStream.running = true;
            }
        }
    }

    Process {
        id: niriEventStream
        running: false
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim().length > 0) {
                    niriDebounceTimer.restart();
                }
            }
        }
        onExited: {
            if (root.moduleActive && root.isNiri) {
                niriRestartTimer.restart();
            }
        }
    }

    Process {
        id: niriPoller
        running: false
        command: [
            "bash",
            "-c",
            "workspaces=$(niri msg -j workspaces 2>/dev/null || echo '[]'); windows=$(niri msg -j windows 2>/dev/null || echo '[]'); echo \"{\\\"workspaces\\\": $workspaces, \\\"windows\\\": $windows}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let wsList = data.workspaces || [];
                    let winList = data.windows || [];
                    let occ = {};
                    for (let i = 0; i < winList.length; i++) {
                        let win = winList[i];
                        if (win.workspace_id !== undefined && win.workspace_id !== null) {
                            occ[win.workspace_id] = true;
                        }
                    }
                    let activeIdx = 0;
                    for (let j = 0; j < wsList.length; j++) {
                        let w = wsList[j];
                        let idx = (w.idx !== undefined ? w.idx : (w.id !== undefined ? w.id : 1)) - 1;
                        if (w.is_focused || w.is_active) {
                            activeIdx = idx;
                        }
                        if (w.active_window_id !== null || occ[w.id] || occ[w.idx]) {
                            occ[idx] = true;
                        }
                    }
                    root.niriActiveIndex = activeIdx;
                    root.niriOccupiedMap = occ;
                } catch (e) {}
            }
        }
    }

    Process {
        id: swayPoller
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t get_workspaces -r 2>/dev/null || echo '[]'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let wsList = JSON.parse(this.text) || [];
                    let occ = {};
                    let activeIdx = 0;
                    for (let i = 0; i < wsList.length; i++) {
                        let w = wsList[i];
                        let num = (w.num !== undefined && w.num > 0) ? w.num : parseInt(w.name);
                        let idx = (!isNaN(num) && num > 0) ? num - 1 : i;
                        if (w.focused) {
                            activeIdx = idx;
                        }
                        occ[idx] = true;
                    }
                    root.swayActiveIndex = activeIdx;
                    root.swayOccupiedMap = occ;
                } catch (e) {}

                swayWaiter.running = false;
                if (root.moduleActive && root.isSway) {
                    swayWaiter.running = true;
                }
            }
        }
    }

    Process {
        id: swayWaiter
        running: false
        command: [
            "bash",
            "-c",
            "swaymsg -t subscribe -m '[\"workspace\", \"window\"]' 2>/dev/null | grep -m 1 -E '\"change\"'"
        ]
        onExited: {
            swayPoller.running = false;
            if (root.moduleActive && root.isSway) {
                swayPoller.running = true;
            }
        }
    }

    property real targetWidth: (moduleActive && workspaceCount > 0 && faceLoader.item) ? faceLoader.item.implicitWidth + s(isCompact ? 18 : 22) : 0
    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    property real wheelAccumulator: 0
    Timer {
        id: wsWheelTimer
        interval: 200
        onTriggered: root.wheelAccumulator = 0
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            wsWheelTimer.restart();
            root.wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(root.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(root.wheelAccumulator / threshold);
                root.wheelAccumulator = root.wheelAccumulator % threshold;

                if (root.workspaceCount > 1) {
                    let cur = root.activeIndex;
                    let nextIndex = 0;
                    if (cur < 0) {
                        nextIndex = steps > 0 ? (root.workspaceCount - 1) : 0;
                    } else {
                        if (steps > 0) {
                            nextIndex = (cur - 1 + root.workspaceCount) % root.workspaceCount;
                        } else if (steps < 0) {
                            nextIndex = (cur + 1) % root.workspaceCount;
                        }
                    }
                    if (nextIndex !== root.activeIndex) {
                        root.focusWorkspace(nextIndex);
                    }
                }
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: s(isCompact ? 18 : 22) / 2
        anchors.verticalCenter: parent.verticalCenter
        source: BarModuleRegistry.variantFaceFile("workspaces", root.workspacesStyle, false)
        onLoaded: {
            attachModel();
            Qt.callLater(attachModel);
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
