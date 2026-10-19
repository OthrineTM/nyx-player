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
    // true where the widget sits on Plasma's own background (a panel popup) instead of a Nyx
    // surface: text then follows the color scheme, whatever the look says
    property bool onPlasmaBackground: false

    property var shared: null
    readonly property bool sharing: !!cfg.styleShared
    readonly property var localLook: Presets.fromConfig(cfg)
    readonly property var look: (sharing && shared) ? Presets.withDefaults(shared) : localLook

    readonly property string preset: look.preset || "custom"
    readonly property string presetName: {
        var p = Presets.find(preset, [])
        return p ? p.name : (preset === "custom" ? "Custom" : preset)
    }
    // the text color the look asks for; `text` below is the one actually used
    // with no surface, theme text would follow the color scheme (dark on Breeze Light) even though
    // it sits on the wallpaper, so see-through looks default to white text with a shadow instead,
    // like desktop icon labels
    readonly property color wantedText: onPlasmaBackground ? themeText
                                        : look.text ? look.text : (opacity < 0.3 ? "#ffffff" : themeText)
    readonly property color baseAccent: accentOverride.a > 0 ? accentOverride : (look.accent ? look.accent : themeAccent)
    // straight on the wallpaper the accent is lifted toward white, so accent text and marks don't sink into it
    readonly property color accent: onWallpaper && !darkText ? Qt.tint(baseAccent, Qt.rgba(1, 1, 1, 0.45)) : baseAccent
    // an empty tint follows the Plasma theme's background, so the Theme look matches the color scheme
    readonly property color tint: look.tint ? look.tint : themeBackground
    readonly property real opacity: Math.max(0, Math.min(100, look.opacity)) / 100
    readonly property real border: Math.max(0, Math.min(100, look.border)) / 100
    readonly property bool borderAccent: !!look.borderAccent
    readonly property real radius: Math.max(0, look.radius)
    readonly property real innerRadius: Math.max(4, radius * 0.6)
    readonly property real sheen: Math.max(0, Math.min(100, look.sheen)) / 100
    readonly property real shadow: Math.max(0, Math.min(100, look.shadow)) / 100
    readonly property real glow: Math.max(0, Math.min(100, look.glow)) / 100
    // see-through looks put text straight on the wallpaper, so they always keep a little shadow
    readonly property real textShadow: Math.max(onWallpaper ? 0.85 : 0, Math.min(100, look.textShadow || 0) / 100)
    // dark text gets a light halo instead of a dark shadow
    readonly property bool darkText: luminance(text) < 0.5
    readonly property color textShadowColor: darkText ? "white" : "black"
    readonly property string font: look.font || ""
    readonly property bool hasSurface: opacity > 0 || border > 0

    // form: how cards, spacing, type and motion look, so styles differ in more than color
    readonly property string cardStyle: ["filled", "outline", "plain"].indexOf(look.card) >= 0 ? look.card : "filled"
    readonly property real space: 0.7 + Math.max(0, Math.min(100, look.space)) / 100 * 0.7      // 0.7 tight - 1.4 airy
    readonly property int numberWeight: 100 + Math.round(Math.max(0, Math.min(100, look.weight)) / 100 * 8) * 100
    readonly property int labelWeight: caps ? Font.DemiBold : Font.Medium
    readonly property bool caps: !!look.caps
    readonly property real tracking: caps ? 0.1 : 0          // label letter spacing, in em
    readonly property string numberFont: look.numFont || font
    readonly property real motion: Math.max(0, Math.min(100, look.motion)) / 100
    readonly property int motionMs: 90 + Math.round(motion * 230)
    function label(t) { return caps ? String(t).toUpperCase() : t }

    // ready-made colors for widgets
    readonly property color surface: Qt.alpha(tint, opacity)
    readonly property color edge: borderAccent ? Qt.alpha(accent, border) : Qt.alpha(text, border * 0.45)
    // see-through looks put text straight on the wallpaper, so secondary text stays stronger there
    readonly property bool seeThrough: opacity < 0.3
    // the wallpaper shows through enough that text needs its own help (shadow, stronger colors)
    readonly property bool onWallpaper: opacity < 0.45 && !onPlasmaBackground

    // Readable text whatever the look and color scheme: on a surface that hides the wallpaper,
    // a text color too close to the surface (white text on Light, dark theme text on a pale
    // tint...) is swapped for near-black or near-white, whichever reads better.
    readonly property color backdrop: Qt.rgba(tint.r * opacity + 0.2 * (1 - opacity),
                                              tint.g * opacity + 0.2 * (1 - opacity),
                                              tint.b * opacity + 0.2 * (1 - opacity), 1)
    readonly property color text: readable(wantedText, 4.5)
    // the same check for any color a widget picks itself (custom clock colors, glows): returns
    // it unchanged unless it would be hard to read on this look's surface
    function readable(c, minRatio) {
        if (onPlasmaBackground || opacity < 0.45 || contrast(c, backdrop) >= (minRatio || 3)) return c
        return contrast("#16141c", backdrop) >= contrast("#f6f4fa", backdrop) ? "#16141c" : "#f6f4fa"
    }
    // secondary text: stronger when the wallpaper shows through, since small faded text on a busy
    // wallpaper is the first thing to become unreadable
    // when the wallpaper shows through, secondary text stays nearly opaque: the wallpaper behind it can be anything
    readonly property color dim: Qt.alpha(text, onWallpaper ? 0.96 : 0.76)
    readonly property color faint: Qt.alpha(text, onWallpaper ? 0.86 : 0.58)
    // inner cards, buttons and tiles sit on any surface, so they are tinted with the text color
    readonly property color card: Qt.alpha(text, 0.06)
    readonly property color cardHover: Qt.alpha(text, 0.11)
    readonly property color cardEdge: Qt.alpha(text, 0.06 + border * 0.14)
    readonly property color track: Qt.alpha(text, 0.12)
    readonly property color active: Qt.alpha(accent, 0.42)
    readonly property color activeHover: Qt.alpha(accent, 0.55)
    readonly property color activeEdge: Qt.alpha(accent, 0.9)
    // readable text on a solid accent fill (not "onAccent": QML reads on + capital as a signal handler)
    readonly property color accentInk: luminance(accent) > 0.6 ? "#14121a" : "#ffffff"

    function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
    // WCAG contrast ratio of two colors, 1 (none) to 21 (black on white)
    function contrast(a, b) {
        function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        function rel(c) { c = Qt.color(c); return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b) }
        var la = rel(a), lb = rel(b)
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
    }

    // Apply a look (a preset or a full set of values) to this widget, and to all widgets when shared.
    function apply(newLook) {
        writeLocal(newLook)
        publish()
    }
    // writes a look into this widget's config without publishing each half-written step
    property bool writing: false
    function writeLocal(l) {
        writing = true
        Presets.toConfig(cfg, l)
        writing = false
    }
    function publish() {
        if (!sharing) return
        s.shared = Presets.fromConfig(cfg)
        exec.run(Presets.writeCommand("style.json", Presets.serialize(s.shared), Qt.btoa))
    }
    // a look changed in this widget's settings becomes the shared look, but only once the
    // shared file has been read: before that, the widget's old local copy would overwrite it
    property bool ready: false
    property bool loaded: false
    onLocalLookChanged: if (ready && loaded && !writing && sharing
                            && Presets.serialize(localLook) !== Presets.serialize(shared || {})) publish()
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
                s.loaded = true
                if (out.length === 0) { s.shared = null; return }
                try {
                    var l = JSON.parse(out)
                    if (!s.shared || Presets.serialize(s.shared) !== Presets.serialize(l)) s.shared = l
                } catch (e) { console.warn("Nyx: bad style.json", e) }
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
