.pragma library
// Built-in looks shared by every Nyx widget. Empty colors mean "follow the Plasma theme".
//   tint      surface color          opacity  surface opacity, 0-100
//   border    edge strength, 0-100   borderAccent  draw the edge in the accent color
//   radius    corner radius in px    sheen    glassy top highlight, 0-100
//   shadow    drop shadow, 0-100     glow     accent glow around the edge, 0-100
//   textShadow  soft shadow under text and icons, for busy wallpapers, 0-100
//   text      text color             accent   accent color         font  font family
// Form, so looks differ in more than color:
//   card      inner cards and rows: "filled", "outline" or "plain" (no boxes, thin dividers)
//   space     padding and gaps, 0 tight - 100 airy     weight  big numbers, 0 thin - 100 black
//   caps      labels in capitals with wide spacing     numFont font for big numbers ("" = font)
//   motion    hover lift and animation, 0 none - 100 lively
var builtin = [
    { preset: "theme",   name: "Theme",   tint: "",        opacity: 85, border: 10, borderAccent: false, radius: 12, sheen: 0,  shadow: 0,  glow: 0,  textShadow: 0,  text: "",        accent: "",        font: "",          card: "filled",  space: 50, weight: 70, caps: false, numFont: "",          motion: 30 },
    { preset: "glass",   name: "Glass",   tint: "#ffffff", opacity: 12, border: 30, borderAccent: false, radius: 22, sheen: 55, shadow: 30, glow: 0,  textShadow: 65, text: "#ffffff", accent: "",        font: "",          card: "filled",  space: 55, weight: 70, caps: false, numFont: "",          motion: 50 },
    { preset: "frost",   name: "Frost",   tint: "#dfe7f5", opacity: 32, border: 45, borderAccent: false, radius: 26, sheen: 30, shadow: 25, glow: 0,  textShadow: 60, text: "#ffffff", accent: "",        font: "",          card: "filled",  space: 65, weight: 40, caps: false, numFont: "",          motion: 45 },
    { preset: "smoke",   name: "Smoke",   tint: "#08080d", opacity: 42, border: 14, borderAccent: false, radius: 20, sheen: 12, shadow: 40, glow: 0,  textShadow: 0,  text: "#f4f3f8", accent: "",        font: "",          card: "filled",  space: 50, weight: 75, caps: false, numFont: "",          motion: 40 },
    { preset: "solid",   name: "Solid",   tint: "#16141d", opacity: 94, border: 6,  borderAccent: false, radius: 14, sheen: 0,  shadow: 45, glow: 0,  textShadow: 0,  text: "#f4f2fa", accent: "",        font: "",          card: "filled",  space: 40, weight: 85, caps: true,  numFont: "",          motion: 30 },
    { preset: "light",   name: "Light",   tint: "#f7f5fb", opacity: 92, border: 10, borderAccent: false, radius: 28, sheen: 0,  shadow: 25, glow: 0,  textShadow: 0,  text: "#1d1b23", accent: "",        font: "",          card: "filled",  space: 65, weight: 55, caps: false, numFont: "",          motion: 50 },
    { preset: "soft",    name: "Soft",    tint: "#2a2140", opacity: 72, border: 0,  borderAccent: false, radius: 34, sheen: 0,  shadow: 35, glow: 0,  textShadow: 0,  text: "#f3eefe", accent: "#c4a7ff", font: "",          card: "filled",  space: 75, weight: 50, caps: false, numFont: "",          motion: 65 },
    { preset: "neon",    name: "Neon",    tint: "#0b0716", opacity: 58, border: 85, borderAccent: true,  radius: 8,  sheen: 0,  shadow: 0,  glow: 70, textShadow: 0,  text: "#f6eeff", accent: "#d946ef", font: "",          card: "outline", space: 45, weight: 60, caps: true,  numFont: "monospace", motion: 70 },
    { preset: "mono",    name: "Mono",    tint: "#0c0f0b", opacity: 88, border: 40, borderAccent: true,  radius: 2,  sheen: 0,  shadow: 30, glow: 0,  textShadow: 0,  text: "#d9f7d2", accent: "#7cff6b", font: "monospace", card: "outline", space: 30, weight: 50, caps: true,  numFont: "monospace", motion: 15 },
    { preset: "minimal", name: "Minimal", tint: "",        opacity: 0,  border: 0,  borderAccent: false, radius: 0,  sheen: 0,  shadow: 0,  glow: 0,  textShadow: 60, text: "#ffffff", accent: "",        font: "",          card: "plain",   space: 60, weight: 15, caps: true,  numFont: "",          motion: 20 },
    { preset: "clear",   name: "Clear",   tint: "",        opacity: 0,  border: 0,  borderAccent: false, radius: 0,  sheen: 0,  shadow: 0,  glow: 0,  textShadow: 0,  text: "",        accent: "",        font: "",          card: "plain",   space: 50, weight: 70, caps: false, numFont: "",          motion: 30 }
]

// form values for looks saved before they existed
var formDefaults = { card: "filled", space: 50, weight: 70, caps: false, numFont: "", motion: 40 }

var keys = ["preset", "tint", "opacity", "border", "borderAccent", "radius", "sheen", "shadow", "glow", "textShadow", "text", "accent", "font",
            "card", "space", "weight", "caps", "numFont", "motion"]

function find(id, user) {
    var all = builtin.concat(user || [])
    for (var i = 0; i < all.length; i++)
        if (all[i].preset === id) return all[i]
    return null
}

// config key for a style value: "opacity" -> "styleOpacity"
function cfgKey(k) {
    return k === "preset" ? "stylePreset" : "style" + k.charAt(0).toUpperCase() + k.slice(1)
}

function fromConfig(cfg) {
    var o = {}
    keys.forEach(function (k) {
        var v = cfg[cfgKey(k)]
        o[k] = (v === undefined && formDefaults[k] !== undefined) ? formDefaults[k] : v
    })
    return o
}

// a look with any missing form values filled in
function withDefaults(look) {
    var o = {}
    keys.forEach(function (k) { o[k] = (look[k] === undefined && formDefaults[k] !== undefined) ? formDefaults[k] : look[k] })
    return o
}

function toConfig(cfg, look) {
    keys.forEach(function (k) { if (look[k] !== undefined) cfg[cfgKey(k)] = look[k] })
}

// one look as text, for the shared style file
function serialize(look) {
    var o = {}
    keys.forEach(function (k) { o[k] = look[k] })
    return JSON.stringify(o)
}

// shell command that writes text to a file under ~/.config/nyx-widgets, safe for any content
function writeCommand(file, text, btoa) {
    return "mkdir -p \"$HOME/.config/nyx-widgets\" && echo " + btoa(text)   // Qt.btoa encodes the text as UTF-8
         + " | base64 -d > \"$HOME/.config/nyx-widgets/" + file + ".tmp\" && mv \"$HOME/.config/nyx-widgets/"
         + file + ".tmp\" \"$HOME/.config/nyx-widgets/" + file + "\""
}

var readStyleCommand = "cat \"$HOME/.config/nyx-widgets/style.json\" 2>/dev/null; true"
var readPresetsCommand = "cat \"$HOME/.config/nyx-widgets/presets.json\" 2>/dev/null; true"
