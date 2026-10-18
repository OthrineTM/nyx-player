import QtQuick
import QtQuick.Effects

// Background panel drawn in the shared Nyx style: tinted surface, edge, glassy sheen,
// soft drop shadow and an optional accent glow. Put content on top of it.
Item {
    id: surf

    required property var style
    property real radius: style.radius
    property color color: style.surface
    property color edgeColor: style.edge

    readonly property bool showShadow: style.shadow > 0 && style.hasSurface
    readonly property bool showGlow: style.glow > 0 && style.hasSurface

    // the shadow is cast by an opaque copy of the shape and cut out where the surface is,
    // so a see-through (glass) surface isn't darkened by its own shadow.
    // The effects are built in Loaders: MultiEffect doesn't notice a source or mask whose
    // layer is switched on later (a look applied after start), and would then draw the
    // opaque copy itself as a solid black panel.
    Loader {
        anchors.fill: parent
        anchors.margins: -64
        active: surf.showShadow
        sourceComponent: Item {
            Item {
                id: shadowLayer
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 64
                    radius: surf.radius
                    color: "black"
                }
            }
            Item {
                id: cutout
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 64
                    radius: surf.radius
                    color: "black"
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: shadowLayer
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: Math.min(1, surf.style.shadow)
                shadowBlur: 1.0
                blurMax: 48
                shadowVerticalOffset: 6 + surf.style.shadow * 12
                shadowScale: 0.98
                maskEnabled: true
                maskInverted: true
                maskSource: cutout
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0.2
            }
        }
    }

    // accent glow around the edge (neon)
    Loader {
        anchors.fill: parent
        anchors.margins: -48
        active: surf.showGlow
        sourceComponent: Item {
            Item {
                id: glowLayer
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 48
                    radius: surf.radius
                    color: "transparent"
                    border.width: 3
                    border.color: surf.style.accent
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: glowLayer
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: surf.style.accent
                shadowOpacity: Math.min(1, surf.style.glow * 1.6)
                shadowBlur: 1.0
                blurMax: 32
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    Rectangle {
        id: base
        anchors.fill: parent
        radius: surf.radius
        color: surf.color
        border.width: surf.style.border > 0 ? 1 : 0
        border.color: surf.edgeColor

        // glassy sheen: a soft light from the top edge
        Rectangle {
            anchors.fill: parent
            anchors.margins: base.border.width
            radius: Math.max(0, surf.radius - base.border.width)
            visible: surf.style.sheen > 0
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.28 * surf.style.sheen) }
                GradientStop { position: 0.38; color: Qt.rgba(1, 1, 1, 0.06 * surf.style.sheen) }
                GradientStop { position: 0.62; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.05 * surf.style.sheen) }
            }
        }
        // bright rim along the top, like light catching the edge of glass
        Rectangle {
            visible: surf.style.sheen > 0 && surf.radius > 0
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.leftMargin: surf.radius * 0.8
            anchors.rightMargin: surf.radius * 0.8
            height: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.55 * surf.style.sheen) }
                GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.55 * surf.style.sheen) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
}
