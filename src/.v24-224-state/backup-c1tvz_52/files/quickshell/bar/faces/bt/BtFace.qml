import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool isDesktop: false
    property string btStatus: "Off"
    property string btIcon: "󰂲"
    property string btDevice: "Off"
    property bool isBtOn: btStatus.toLowerCase() === "enabled" || btStatus.toLowerCase() === "on"
    property bool showLayout: (!module || module.moduleActive) && (barWindow ? (barWindow.isStartupReady && barWindow.isDataReady) : true)
    property alias btPill: btPill

    Component.onCompleted: {
        updateBtData();
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                chassisDetector.running = false;
            } else {
                chassisDetector.running = true;
                root.updateBtData();
            }
        }
    }

    Process {
        id: chassisDetector
        running: !module || module.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    function getBtDevicesList() {
        let adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.devices) return [];
        let devs = adapter.devices.values || adapter.devices;
        let list = [];
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (d) list.push(d);
        }
        return list;
    }

    function updateBtData() {
        let adapter = Bluetooth.defaultAdapter;
        let enabled = adapter ? adapter.enabled : false;

        if (!enabled) {
            btStatus = "Off";
            btIcon = "󰂲";
            btDevice = "Off";
            return;
        }

        btStatus = "On";

        let connectedDev = null;
        let devList = getBtDevicesList();

        for (let i = 0; i < devList.length; i++) {
            let d = devList[i];
            if (d && d.connected) {
                connectedDev = d;
                break;
            }
        }

        if (connectedDev) {
            let name = connectedDev.name || connectedDev.deviceName || connectedDev.address || "";
            let iconType = connectedDev.icon || "";
            let typeLower = iconType.toLowerCase();
            let nameLower = name.toLowerCase();

            let icon = "󰂯";
            if (typeLower.indexOf("headset") !== -1 || typeLower.indexOf("headphone") !== -1 || nameLower.indexOf("headphone") !== -1 || nameLower.indexOf("buds") !== -1 || nameLower.indexOf("pods") !== -1) icon = "🎧";
            else if (typeLower.indexOf("audio") !== -1 || typeLower.indexOf("speaker") !== -1 || typeLower.indexOf("card") !== -1 || nameLower.indexOf("speaker") !== -1) icon = "📻";
            else if (typeLower.indexOf("phone") !== -1 || nameLower.indexOf("phone") !== -1 || nameLower.indexOf("iphone") !== -1 || nameLower.indexOf("android") !== -1) icon = "📱";
            else if (typeLower.indexOf("mouse") !== -1 || nameLower.indexOf("mouse") !== -1) icon = "󰍽";
            else if (typeLower.indexOf("keyboard") !== -1 || nameLower.indexOf("keyboard") !== -1) icon = "⌨️";
            else if (typeLower.indexOf("controller") !== -1 || nameLower.indexOf("controller") !== -1) icon = "🎮";

            btIcon = icon;
            btDevice = name;
        } else {
            btIcon = "󰂯";
            btDevice = "On";
        }
    }

    Item {
        visible: false
        Connections {
            target: Bluetooth
            ignoreUnknownSignals: true
            function onDefaultAdapterChanged() { root.updateBtData(); }
        }
        Connections {
            target: Bluetooth.defaultAdapter || null
            ignoreUnknownSignals: true
            function onEnabledChanged() { root.updateBtData(); }
            function onDiscoveringChanged() { root.updateBtData(); }
            function onDevicesChanged() { root.updateBtData(); }
        }
        Connections {
            target: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.devices) ? Bluetooth.defaultAdapter.devices : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { root.updateBtData(); }
            function onObjectRemovedPost(object, index) { root.updateBtData(); }
            function onCountChanged() { root.updateBtData(); }
        }
        Repeater {
            id: btDeviceRepeater
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
            Item {
                property var device: modelData
                Component.onCompleted: root.updateBtData()
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onConnectedChanged() { root.updateBtData(); }
                    function onStateChanged() { root.updateBtData(); }
                    function onPairedChanged() { root.updateBtData(); }
                    function onNameChanged() { root.updateBtData(); }
                    function onDeviceNameChanged() { root.updateBtData(); }
                    function onIconChanged() { root.updateBtData(); }
                }
            }
        }
    }

    property real targetWidth: ((!module || module.moduleActive) && !isDesktop && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    property bool isFaceVisible: showLayout && !isDesktop && targetWidth > 0

    implicitWidth: targetWidth
    implicitHeight: parent ? parent.height : 0

    transform: Translate {
        x: root.showLayout ? 0 : (barWindow ? barWindow.s(60) : 60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)

        ClickButton {
            id: btPill
            property bool initAnimTrigger: root.showLayout
            property bool isActive: root.isBtOn

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(root.isCompact ? 156 : 160) : (root.isCompact ? 156 : 160)
            visible: targetWidth > 0
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(root.isCompact ? 10 : 12) : (root.isCompact ? 10 : 12)
            buttonIcon: root.btIcon
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            buttonText: root.btDevice
            textFontSize: barWindow ? barWindow.s(root.isCompact ? 11 : 12) : (root.isCompact ? 11 : 12)
            accentColor: isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: root.isDesktop ? 0 : implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: btPill.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network bt"])
        }
    }
}
