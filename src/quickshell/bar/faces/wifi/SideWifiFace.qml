import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null

    property bool isDesktop: false
    property bool showLayout: (!module || module.moduleActive) && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiBtn

    property string ethStatus: "Ethernet"
    property string wifiStatus: "Off"
    property string wifiIcon: "󰤮"
    property string wifiSsid: ""
    property bool isWifiOn: Networking.wifiEnabled
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

    property var ethDevice: null
    property var wifiDevice: null

    Component.onCompleted: {
        findDevices();
        updateNetworkData();
    }

    Connections {
        target: module || null
        function onModuleActiveChanged() {
            if (module && !module.moduleActive) {
                chassisDetector.running = false;
            } else {
                chassisDetector.running = true;
                root.findDevices();
                root.updateNetworkData();
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

    function isEthDevice(dev) {
        return !!dev && dev.type === DeviceType.Wired;
    }

    function isWifiDevice(dev) {
        return !!dev && dev.type === DeviceType.Wifi;
    }

    function findDevices() {
        if (!Networking || !Networking.devices) return;
        let devs = Networking.devices.values || Networking.devices;
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (!d) continue;
            if (!root.ethDevice && isEthDevice(d)) {
                root.ethDevice = d;
            } else if (!root.wifiDevice && isWifiDevice(d)) {
                root.wifiDevice = d;
            }
        }
    }

    function getWifiNetworksList() {
        if (!wifiDevice || !wifiDevice.networks) return [];
        let nets = wifiDevice.networks.values || wifiDevice.networks;
        let list = [];
        let count = nets.length !== undefined ? nets.length : (nets.count !== undefined ? nets.count : 0);
        for (let i = 0; i < count; i++) {
            let n = nets[i] !== undefined ? nets[i] : (nets.get ? nets.get(i) : null);
            if (n) list.push(n);
        }
        return list;
    }

    function updateNetworkData() {
        findDevices();

        let isWifiEnabled = Networking.wifiEnabled;
        wifiStatus = isWifiEnabled ? "Enabled" : "Off";

        if (ethDevice) {
            if (ethDevice.connected) {
                ethStatus = "Connected";
            } else if (ethDevice.hasLink) {
                ethStatus = "Disconnected";
            } else {
                ethStatus = "Ethernet";
            }
        } else {
            ethStatus = "Ethernet";
        }

        if (!isWifiEnabled) {
            wifiSsid = "";
            wifiIcon = "󰤮";
            return;
        }

        let connectedNet = null;
        let netList = getWifiNetworksList();
        for (let i = 0; i < netList.length; i++) {
            let n = netList[i];
            if (n && n.connected) {
                connectedNet = n;
                break;
            }
        }

        if (connectedNet) {
            wifiSsid = connectedNet.name || connectedNet.ssid || "";
            let sig = connectedNet.signalStrength !== undefined ? Math.round(connectedNet.signalStrength * (connectedNet.signalStrength <= 1 ? 100 : 1)) : 100;
            if (sig >= 80) wifiIcon = "󰤨";
            else if (sig >= 60) wifiIcon = "󰤥";
            else if (sig >= 40) wifiIcon = "󰤢";
            else if (sig >= 20) wifiIcon = "󰤟";
            else wifiIcon = "󰤯";
        } else {
            wifiSsid = "";
            wifiIcon = "󰤯";
        }
    }

    Item {
        visible: false

        Connections {
            target: Networking
            ignoreUnknownSignals: true
            function onWifiEnabledChanged() { root.updateNetworkData(); }
            function onDevicesChanged() {
                root.findDevices();
                root.updateNetworkData();
            }
        }

        Connections {
            target: Networking.devices || null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) {
                root.findDevices();
                root.updateNetworkData();
            }
            function onObjectRemovedPost(object, index) {
                root.findDevices();
                root.updateNetworkData();
            }
            function onCountChanged() {
                root.findDevices();
                root.updateNetworkData();
            }
        }

        Connections {
            target: root.ethDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { root.updateNetworkData(); }
            function onStateChanged() { root.updateNetworkData(); }
            function onHasLinkChanged() { root.updateNetworkData(); }
        }

        Connections {
            target: root.wifiDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { root.updateNetworkData(); }
            function onStateChanged() { root.updateNetworkData(); }
            function onNetworksChanged() { root.updateNetworkData(); }
        }

        Connections {
            target: (root.wifiDevice && root.wifiDevice.networks) ? root.wifiDevice.networks : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { root.updateNetworkData(); }
            function onObjectRemovedPost(object, index) { root.updateNetworkData(); }
            function onCountChanged() { root.updateNetworkData(); }
        }

        Repeater {
            id: netDeviceRepeater
            model: Networking.devices
            Item {
                property var device: modelData
                Component.onCompleted: {
                    if (device && device.type === DeviceType.Wired) {
                        root.ethDevice = device;
                    } else if (device && device.type === DeviceType.Wifi) {
                        root.wifiDevice = device;
                    }
                    root.updateNetworkData();
                }
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onStateChanged() { root.updateNetworkData(); }
                    function onConnectedChanged() { root.updateNetworkData(); }
                    function onHasLinkChanged() { root.updateNetworkData(); }
                }
            }
        }

        Repeater {
            id: wifiNetworkRepeater
            model: root.wifiDevice ? root.wifiDevice.networks : null
            Item {
                property var network: modelData
                Component.onCompleted: root.updateNetworkData()
                Connections {
                    target: network || null
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { root.updateNetworkData(); }
                    function onStateChanged() { root.updateNetworkData(); }
                    function onConnectedChanged() { root.updateNetworkData(); }
                    function onNameChanged() { root.updateNetworkData(); }
                    function onSsidChanged() { root.updateNetworkData(); }
                }
            }
        }
    }

    property real targetHeight: wifiBtn.height + (barWindow ? barWindow.s(root.isCompact ? 8 : 10) : (root.isCompact ? 8 : 10))
    property bool isFaceVisible: showLayout && targetHeight > 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    ClickButton {
        id: wifiBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        horizontalPadding: 0
        buttonIcon: root.showEthernet ? "󰈀" : root.wifiIcon
        iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
        accentColor: root.isActive ? (root.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: root.isActive ? ThemeBackend.base : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle network wifi"])
    }
}
