import QtQuick

Item {
    id: root
    property string text: ""
    property color color: "white"
    property int pixelSize: 18
    property bool opticalCentering: true
    implicitWidth: pixelSize + 8
    implicitHeight: pixelSize + 8
    FontLoader { id: iconFont; source: "../../assets/fonts/IosevkaNerdFont-Regular.ttf" }
    TextMetrics {
        id: ink
        text: glyph.text
        font: glyph.font
        renderType: Text.NativeRendering
    }
    Text {
        id: glyph
        text: root.text
        color: root.color
        font.family: iconFont.status === FontLoader.Ready ? iconFont.name : "Iosevka Nerd Font"
        font.pixelSize: root.pixelSize
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        // tightBoundingRect is baseline-relative; baselineOffset maps it to Text coordinates.
        x: root.opticalCentering ? (root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x : (root.width - width) / 2
        y: root.opticalCentering ? (root.height - ink.tightBoundingRect.height) / 2 - ink.tightBoundingRect.y - baselineOffset : (root.height - height) / 2
    }
}
