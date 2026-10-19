import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Opens what a widget's click is set to. The setting is one or more choices separated by ";",
// tried in order until one works:
//   an app's desktop name    org.kde.plasma-systemmonitor   (skipped when it isn't installed)
//   a web address or file    https://example.com, /home/me/Pictures
//   any other command        kcmshell6 kcm_clock
// %name in the setting is replaced by the widget's values, e.g. %lat and %lon in Nyx Weather.
QtObject {
    id: launcher

    property string target: ""
    readonly property bool active: target.trim().length > 0

    property P5Support.DataSource runner: P5Support.DataSource {
        engine: "executable"
        onNewData: function (source) { disconnectSource(source) }
    }

    function quote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'" }

    function step(choice) {
        if (choice.charAt(0) === "~")
            return "xdg-open \"$HOME\"" + quote(choice.slice(1))
        if (/^[a-z][a-z0-9+.-]*:\/\//i.test(choice) || choice.charAt(0) === "/")
            return "xdg-open " + quote(choice)
        if (/^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+$/.test(choice)) {
            // an app's desktop name: launch it only if its .desktop file exists in the usual places
            return "f=$(for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" $(echo \"${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\" | tr : ' ') "
                 + "/var/lib/flatpak/exports/share \"$HOME/.local/share/flatpak/exports/share\"; do "
                 + "[ -f \"$d/applications/" + choice + ".desktop\" ] && echo \"$d/applications/" + choice + ".desktop\" && break; done) "
                 + "&& [ -n \"$f\" ] && kioclient exec \"$f\""
        }
        return "(" + choice + ")"
    }

    function open(values) {
        var spec = target
        var vals = values || {}
        Object.keys(vals).forEach(function (k) { spec = spec.split("%" + k).join(String(vals[k])) })
        var choices = spec.split(";").map(function (c) { return c.trim() }).filter(function (c) { return c.length > 0 })
        if (choices.length === 0) return
        var script = choices.map(step).join(" || ")
        runner.connectSource("setsid -f sh -c " + quote(script) + " >/dev/null 2>&1")
    }
}
