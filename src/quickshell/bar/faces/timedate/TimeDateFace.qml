import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"
import "../../"

Item {
    id: root

    property var module: null
    property var widget: root

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.configRevision++; }
        function onRawSettingsChanged() { root.configRevision++; }
    }

    property string timeStyle: {
        let dummy = configRevision;
        if (module && module.variant) return module.variant;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeStyle) return Config.rawSettings.bar.timeStyle;
        }
        return "classic";
    }

    property bool showDate: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeShowDate !== undefined) return Config.rawSettings.bar.timeShowDate;
            if (Config.rawSettings.bar.showDate !== undefined) return Config.rawSettings.bar.showDate;
        }
        return true;
    }

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : ""
    readonly property string timeOnlyStr: (typeof DateTime !== "undefined" && DateTime.timeOnly) ? DateTime.timeOnly : ""
    readonly property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : (DateTime.time ? DateTime.time.split(":")[0] : "")
    readonly property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : (DateTime.time ? DateTime.time.split(":")[1] : "")
    readonly property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : ""
    readonly property string fullDateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : ""
    property int typeInIndex: 0
    property string dateStr: fullDateStr.substring(0, typeInIndex)

    onFullDateStrChanged: {
        if (typeInIndex >= fullDateStr.length) {
            typeInIndex = fullDateStr.length;
        }
    }

    Timer {
        id: typewriterTimer
        interval: 30
        running: (!module || module.moduleActive) && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property real horizontalPadding: s(isCompact ? 12 : 14)
    property real targetWidth: (faceLoader.item ? faceLoader.item.implicitWidth : 0) + (horizontalPadding * 2)

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", Caching.serpantinumDir + "/scripts/qs_manager.sh", "toggle", "calendar"]);
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.centerIn: parent
        source: BarModuleRegistry.variantFaceFile("timedate", root.timeStyle, false)
        onLoaded: {
            if (item) item.widget = root;
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: root
    }
}
