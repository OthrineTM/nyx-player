import QtQuick
import org.kde.plasma.plasma5support as P5Support
import "NyxPresets.js" as Presets

// The look shared by all Nyx widgets: surface, edge, corners, shine, shadow, glow and colors.
// With "Share this look" on, values come from ~/.config/nyx-widgets/style.json, so changing the
// look in one widget changes every widget that shares it.
QtObject {
    id: s

    required property var cfg
    // the Plasma theme's colors, passed in from the widget root
    property color themeText: "white"
    property color themeAccent: "#3daee9"
    property color themeBackground: "black"
    // set to override the accent (e.g. colors taken from album art); transparent = none
    property color accentOverride: "transparent"

    property var shared: null
    readonly property bool sharing: !!cfg.styleShared
    readonly property var localLook: Presets.fromConfig(cfg)
    readonly property var look: (sharing && shared) ? shared : localLook

    readonly property string preset: look.preset || "custom"
    readonly property string presetName: {
        var p = Presets.find(preset, [])
        return p ? p.name : (preset === "custom" ? "Custom" : preset)
    }
    readonly property color text: look.text ? look.text : themeText
    readonly property color accent: accentOverride.a > 0 ? accentOverride : (look.accent ? look.accent : themeAccent)
    readonly property color tint: look.tint ? look.tint : themeText
    readonly property real opacity: Math.max(0, Math.min(100, look.opacity)) / 100
    readonly property real border: Math.max(0, Math.min(100, look.border)) / 100
    readonly property bool borderAccent: !!look.borderAccent
    readonly property real radius: Math.max(0, look.radius)
    readonly property real innerRadius: Math.max(4, radius * 0.6)
    readonly property real sheen: Math.max(0, Math.min(100, look.sheen)) / 100
    readonly property real shadow: Math.max(0, Math.min(100, look.shadow)) / 100
    readonly property real glow: Math.max(0, Math.min(100, look.glow)) / 100
    readonly property real textShadow: Math.max(0, Math.min(100, look.textShadow || 0)) / 100
    readonly property string font: look.font || ""
    readonly property bool hasSurface: opacity > 0 || border > 0

    // ready-made colors for widgets
    readonly property color surface: Qt.alpha(tint, opacity)
    readonly property color edge: borderAccent ? Qt.alpha(accent, border) : Qt.alpha(text, border * 0.45)
    readonly property color dim: Qt.alpha(text, 0.68)
    readonly property color faint: Qt.alpha(text, 0.42)
    // inner cards, buttons and tiles sit on any surface, so they are tinted with the text color
    readonly property color card: Qt.alpha(text, 0.06)
    readonly property color cardHover: Qt.alpha(text, 0.11)
    readonly property color cardEdge: Qt.alpha(text, 0.06 + border * 0.14)
    readonly property color track: Qt.alpha(text, 0.12)
    readonly property color active: Qt.alpha(accent, 0.42)
    readonly property color activeHover: Qt.alpha(accent, 0.55)
    readonly property color activeEdge: Qt.alpha(accent, 0.9)
    // readable text on a solid accent fill
    readonly property color onAccent: luminance(accent) > 0.6 ? "#14121a" : "#ffffff"

    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    // Apply a look (a preset or a full set of values) to this widget, and to all widgets when shared.
    function apply(newLook) {
        Presets.toConfig(cfg, newLook)
        publish()
    }
    function publish() {
        if (!sharing) return
        s.shared = Presets.fromConfig(cfg)
        exec.run(Presets.writeCommand("style.json", Presets.serialize(s.shared), Qt.btoa))
    }
    // a look changed in this widget's settings becomes the shared look
    property bool ready: false
    onLocalLookChanged: if (ready && Presets.serialize(localLook) !== Presets.serialize(shared || {})) publish()
    function applyPreset(id) {
        var p = Presets.find(id, userPresets)
        if (p) apply(p)
    }
    // the next built-in look, for the "Next Style" action
    function nextPreset() {
        var b = Presets.builtin
        for (var i = 0; i < b.length; i++)
            if (b[i].preset === preset) return b[(i + 1) % b.length]
        return b[0]
    }

    property var userPresets: []

    property P5Support.DataSource exec: P5Support.DataSource {
        engine: "executable"
        function run(cmd) { connectSource(cmd) }
        onNewData: function (source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (source === Presets.readStyleCommand) {
                if (out.length === 0) { s.shared = null; return }
                if (s.shared && Presets.serialize(s.shared) === Presets.serialize(JSON.parse(out))) return
                try { s.shared = JSON.parse(out) } catch (e) { console.warn("Nyx: bad style.json", e) }
            } else if (source === Presets.readPresetsCommand) {
                try { s.userPresets = out.length > 0 ? JSON.parse(out) : [] } catch (e) { s.userPresets = [] }
            }
        }
    }

    // follow changes made by other widgets
    property Timer poll: Timer {
        interval: 3000
        repeat: true
        running: s.sharing
        triggeredOnStart: true
        onTriggered: s.exec.run(Presets.readStyleCommand)
    }
    Component.onCompleted: {
        exec.run(Presets.readPresetsCommand)
        ready = true
    }
}
