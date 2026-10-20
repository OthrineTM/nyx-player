import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Effects
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: root

    // colors come from the shared Nyx style (which follows the Plasma theme by default),
    // with the accent optionally taken from the album art
    readonly property color themeText: Kirigami.Theme.textColor
    readonly property color themeAccent: Kirigami.Theme.highlightColor
    readonly property color themeBackground: Kirigami.Theme.backgroundColor
    property NyxStyle style: NyxStyle {
        cfg: root.cfg
        themeText: root.themeText
        themeAccent: root.themeAccent
        themeBackground: root.themeBackground
        // in the panel popup the background is Plasma's, so text keeps the color scheme's colors
        onPlasmaBackground: !root.onDesktop
        accentOverride: root.cfg.accentFromArt && root.artUrl.length > 0 ? root.artAccent : "transparent"
    }
    // set by the ArtProbe in whichever representation is showing (a canvas needs a window to paint)
    property color artHighlight: "#8a7fb0"
    // the art's most colorful tone, lifted so it reads on dark and light surfaces
    readonly property color artAccent: Qt.hsla(root.artHighlight.hslHue, Math.max(0.45, root.artHighlight.hslSaturation),
                                               Math.min(0.72, Math.max(0.5, root.artHighlight.hslLightness)), 1)
    readonly property color cAccent: style.accent
    readonly property color cText: style.text
    readonly property color cMuted: style.faint
    readonly property color cBg: Kirigami.Theme.backgroundColor

    readonly property var cfg: Plasmoid.configuration
    readonly property bool onDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property var cardNames: ["Album", "Wide", "Vinyl", "Effects", "Visualizer"]

    Plasmoid.backgroundHints: onDesktop ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    preferredRepresentation: onDesktop ? fullRepresentation : compactRepresentation
    readonly property string helper: Qt.resolvedUrl("../code/ee.sh").toString().replace("file://", "")

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Prefer This Computer's Players"
            icon.name: "computer"
            checkable: true
            checked: root.cfg.preferLocal
            onTriggered: root.cfg.preferLocal = checked
        },
        PlasmaCore.Action {
            visible: root.onDesktop
            text: "Next Card: " + root.cardNames[(root.cfg.deskFace + 1) % root.cardNames.length]
            icon.name: "view-preview"
            onTriggered: root.cfg.deskFace = (root.cfg.deskFace + 1) % root.cardNames.length
        },
        PlasmaCore.Action {
            text: "Next Style: " + root.style.nextPreset().name
            icon.name: "preferences-desktop-theme"
            onTriggered: root.style.apply(root.style.nextPreset())
        }
    ]

    toolTipMainText: root.title
    toolTipSubText: root.artist

    // ---- player -------------------------------------------------------
    Mpris.Mpris2Model { id: mpris }
    Instantiator {
        id: allPlayers
        model: mpris
        delegate: QtObject { readonly property var container: model.container }
    }
    // Chromium keeps a dead MPRIS entry after the tab closes; require metadata.
    function hasMeta(p) { return !!p && !!(p.track || p.artist) }
    // Players bridged from a phone by KDE Connect rank below local ones.
    function isRemote(p) { return !!p && String(p.desktopEntry).indexOf("org.kde.kdeconnect") === 0 }
    function isPlaying(p) { return p.playbackStatus === Mpris.PlaybackStatus.Playing }
    // Every player with something loaded, for the switcher in the popup.
    // KDE Connect can list the same phone app twice; keep one per name, the playing one.
    readonly property var players: {
        var out = [], seen = {}
        for (var i = 0; i < allPlayers.count; i++) {
            var o = allPlayers.objectAt(i)
            var p = o ? o.container : null
            if (!hasMeta(p)) continue
            if (seen[p.identity] === undefined) { seen[p.identity] = out.length; out.push(p) }
            else if (isPlaying(p) && !isPlaying(out[seen[p.identity]])) out[seen[p.identity]] = p
        }
        return out
    }
    // A player picked by hand wins while it exists; otherwise choose automatically.
    readonly property var pinned: {
        for (var i = 0; i < players.length; i++)
            if (players[i].identity === cfg.pinnedPlayer) return players[i]
        return null
    }
    // Plasma's current player can be an idle app (e.g. an Electron app with no media),
    // so rank by local (when preferred), then playing. Spotify Connect makes the phone
    // play while the local app sits paused, so "local" must outrank "playing".
    readonly property var autoPlayer: {
        var best = null, bestRank = -1
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            var rank = (cfg.preferLocal && isRemote(p) ? 0 : 2) + (isPlaying(p) ? 1 : 0)
            if (rank > bestRank) { best = p; bestRank = rank }
        }
        return best || mpris.currentPlayer
    }
    readonly property var player: pinned || autoPlayer
    readonly property bool ready: hasMeta(player)
    readonly property bool playing: ready && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string title: ready ? player.track : "Nothing playing"
    readonly property string artist: ready ? player.artist : ""
    readonly property string artUrl: ready ? player.artUrl : ""
    readonly property string source: ready ? player.identity : ""
    readonly property real length: ready ? player.length : 0      // µs
    readonly property real position: ready ? player.position : 0  // µs

    function fmtTime(us) {
        var s = Math.max(0, Math.floor(us / 1000000))
        var m = Math.floor(s / 60)
        s = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.player.updatePosition()
    }

    // ---- audio visualizer -----------------------------------------------
    // cava runs in the background and keeps overwriting one line of bar heights in
    // $XDG_RUNTIME_DIR (a RAM disk); the Visualizer card reads that line while music plays.
    property var levels: []
    property var peaks: []           // falling peak markers, same scale as levels (0-100)
    property bool cavaOk: false
    property bool cavaChecked: false
    property bool cavaLaunched: false
    readonly property bool vizShown: onDesktop && cfg.deskFace === 4
    // windows can hide the desktop card; then the visualizer pauses (setting vizPause:
    // 0 never, 1 a maximized or fullscreen window on this screen, 2 any window over the card)
    property bool vizCovered: false
    readonly property bool vizActive: vizShown && playing && !vizCovered
    readonly property int vizBars: Math.max(4, Math.min(64, cfg.visualizerBars))
    readonly property int vizFps: Math.max(10, Math.min(60, cfg.vizFps || 25))
    // everything cava itself is started with; a change restarts it
    readonly property string vizConf: "framerate = " + vizFps + "\\nbars = " + vizBars
        + "\\nsensitivity = " + Math.max(10, Math.min(300, cfg.vizSens))
        + "\\nautosens = " + (cfg.vizAutoSens ? 1 : 0)
        + "\\n[smoothing]\\nnoise_reduction = " + Math.max(0, Math.min(100, cfg.vizSmooth))
    readonly property string cavaPattern: "'^cava -p .*/nyx-player-cava[.]conf$'"
    readonly property string cavaReadCmd: 'cat "${XDG_RUNTIME_DIR:-/tmp}/nyx-player-cava" 2>/dev/null'

    // (re)starts cava; the file names are built from $f so this command line
    // never matches cavaPattern itself
    function cavaStartCmd() {
        return 'command -v cava >/dev/null || exit 3; '
            + 'pkill -f ' + cavaPattern + '; sleep 0.2; '
            + 'f="${XDG_RUNTIME_DIR:-/tmp}/nyx-player-cava"; '
            + "printf '[general]\\n" + vizConf + "\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\n"
            + "data_format = ascii\\nascii_max_range = 100\\nbar_delimiter = 59\\nframe_delimiter = 10\\n' "
            + ' > "$f.conf"; '
            + "setsid sh -c 'cava -p \"$0.conf\" | while IFS= read -r l; do printf \"%s\\n\" \"$l\" > \"$0\"; done' "
            + '"$f" >/dev/null 2>&1 &'
    }
    function cavaStart() { cavaLaunched = true; viz.run(cavaStartCmd()) }
    function cavaStop() { cavaLaunched = false; cavaOk = false; viz.run("pkill -f " + cavaPattern + "; true") }

    P5Support.DataSource {
        id: viz
        engine: "executable"
        function run(cmd) { if (connectedSources.indexOf(cmd) < 0) connectSource(cmd) }
        onNewData: function (source, data) {
            disconnectSource(source)
            if (source === root.cavaReadCmd) {
                var v = (data["stdout"] || "").trim().split(";").filter(function (x) { return x.length > 0 })
                if (v.length === root.vizBars) {
                    var lv = v.map(Number)
                    if (root.cfg.vizPeaks) {
                        // a peak falls the full height in about 1.2 s, whatever the frame rate
                        var drop = 100 / (root.vizFps * 1.2)
                        var old = root.peaks.length === lv.length ? root.peaks : []
                        root.peaks = lv.map(function (x, i) { return Math.max(x, (old[i] || 0) - drop) })
                    }
                    root.levels = lv
                }
            } else if (source.indexOf("command -v cava") === 0) {
                root.cavaOk = data["exit code"] === 0
                root.cavaChecked = true
            }
        }
    }

    Timer {
        interval: Math.round(1000 / root.vizFps)
        repeat: true
        running: root.vizActive && root.cavaOk
        onTriggered: viz.run(root.cavaReadCmd)
        onRunningChanged: if (!running) { root.levels = []; root.peaks = [] }
    }

    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.TasksModel {
        id: deskWindows
        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: Plasmoid.containment.screenGeometry
        filterByScreen: true
        filterByCurrentVirtualDesktop: true
        activity: activityInfo.currentActivity
        filterByActivity: true
        filterMinimized: true
        filterHidden: true
    }
    Instantiator {
        id: deskWindowList
        active: root.vizShown && root.cfg.vizPause > 0
        model: deskWindows
        delegate: QtObject {
            readonly property bool win: model.IsWindow === true
            readonly property bool big: model.IsMaximized === true || model.IsFullScreen === true
            readonly property rect geo: model.Geometry
            onBigChanged: coverCheck.restart()
            onGeoChanged: coverCheck.restart()
        }
        onObjectAdded: coverCheck.restart()
        onObjectRemoved: coverCheck.restart()
        onActiveChanged: coverCheck.restart()
    }
    Timer {
        id: coverCheck
        interval: 250
        onTriggered: {
            var mode = root.cfg.vizPause, covered = false
            if (deskWindowList.active && mode > 0) {
                var sg = Plasmoid.containment.screenGeometry
                var p = root.mapToItem(null, 0, 0)
                var x1 = sg.x + p.x, y1 = sg.y + p.y, x2 = x1 + root.width, y2 = y1 + root.height
                for (var i = 0; i < deskWindowList.count && !covered; i++) {
                    var w = deskWindowList.objectAt(i)
                    if (!w || !w.win) continue
                    if (mode === 1) covered = w.big
                    else covered = w.geo.x < x2 && w.geo.x + w.geo.width > x1
                                   && w.geo.y < y2 && w.geo.y + w.geo.height > y1
                }
            }
            root.vizCovered = covered
        }
    }

    // cava starts the first time music plays on the Visualizer card and stops when the card
    // goes or gets covered by a window
    onVizActiveChanged: {
        if (vizActive && !cavaLaunched) cavaStart()
        else if (!vizActive && vizCovered && cavaLaunched) cavaStop()
    }
    onVizShownChanged: if (!vizShown && cavaLaunched) cavaStop()
    onVizConfChanged: if (cavaLaunched) cavaStart()
    Component.onDestruction: if (cavaLaunched) cavaStop()

    // ---- Easy Effects -------------------------------------------------
    property var eePresets: []       // raw preset names
    property string eeCurrent: ""
    property bool eeRunning: false
    property bool eeOn: true
    property string sinkName: ""
    property var eeEffects: []       // effects in the current preset, in order

    // "rock-min"/"rock-max" -> one group "rock" with two variants
    readonly property var eeGroups: {
        var map = {}, order = []
        eePresets.forEach(function (p) {
            var m = p.match(/^(.*)-(min|max)$/)
            var base = m ? m[1] : p
            if (!(base in map)) { map[base] = {}; order.push(base) }
            map[base][m ? m[2] : "single"] = p
        })
        // first words shared by several multi-word presets ("GentleDynamics X") are dropped
        var firstCount = {}
        order.forEach(function (b) { var w = b.split(" ")[0]; firstCount[w] = (firstCount[w] || 0) + 1 })
        return order.map(function (b) {
            var words = b.split(" ")
            var label = (words.length > 1 && firstCount[words[0]] > 1) ? words.slice(1).join(" ") : b
            var pretty = { eq: "EQ", mc: "MC", edm: "EDM", hifi: "Hi-Fi", kpop: "K-Pop", lofi: "Lo-Fi" }
            label = label.replace(/[-_]/g, " ").split(" ").map(function (w) {
                return pretty[w.toLowerCase()] || w.charAt(0).toUpperCase() + w.slice(1)
            }).join(" ")
            return { base: b, label: label, variants: map[b] }
        })
    }
    // the presets offered as buttons and by the arrows: everything not hidden on the Presets page
    readonly property var visibleGroups: eeGroups.filter(function (g) {
        return (cfg.hiddenPresets || []).indexOf(g.base) < 0
    })
    readonly property var currentGroup: {
        for (var i = 0; i < eeGroups.length; i++) {
            var v = eeGroups[i].variants
            for (var k in v) if (v[k] === eeCurrent) return eeGroups[i]
        }
        return null
    }
    readonly property string currentVariant: {
        var m = eeCurrent.match(/-(min|max)$/)
        return m ? m[1] : ""
    }

    // "bass_enhancer" -> "Bass Enhancer"
    function effectLabel(id) {
        var names = { autogain: "Auto Gain", bass_enhancer: "Bass Enhancer", bass_loudness: "Bass Loudness",
                      crystalizer: "Crystalizer", deesser: "De-esser", exciter: "Exciter", rnnoise: "Noise Reduction",
                      stereo_tools: "Stereo Tools", multiband_compressor: "Multiband Compressor" }
        return names[id] || id.replace(/_/g, " ").replace(/\b\w/g, function (c) { return c.toUpperCase() })
    }
    // step through preset groups from the desktop Effects card
    // (hidden presets are skipped; from a hidden one it starts at either end)
    function stepPreset(d) {
        var list = visibleGroups
        if (list.length === 0) return
        var i = currentGroup ? list.indexOf(currentGroup) : -1
        if (i < 0) i = d > 0 ? -1 : list.length
        loadPreset(presetFor(list[(i + d + list.length) % list.length]))
    }

    function presetFor(group) {
        var v = group.variants
        return v[cfg.variant] || v.max || v.min || v.single
    }

    function loadPreset(name) {
        root.eeCurrent = name          // optimistic, confirmed by the refresh
        exec.run("bash '" + root.helper + "' load '" + name.replace(/'/g, "'\\''") + "'")
        refreshTimer.restart()
    }

    function setEffects(on) {
        root.eeOn = on
        exec.run("bash '" + root.helper + "' bypass " + (on ? 2 : 1))
        refreshTimer.restart()
    }

    function refresh() { exec.run("bash '" + root.helper + "' state") }

    Timer { id: refreshTimer; interval: 1500; onTriggered: root.refresh() }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        function run(cmd) { connectSource(cmd) }
        onNewData: function (source, data) {
            disconnectSource(source)
            if (!source.endsWith("' state")) return
            var presets = [], effects = []
            ;(data["stdout"] || "").split("\n").forEach(function (line) {
                var i = line.indexOf("=")
                if (i < 0) return
                var k = line.slice(0, i), v = line.slice(i + 1)
                if (k === "preset") presets.push(v)
                else if (k === "effect") effects.push(v)
                else if (k === "current") root.eeCurrent = v
                else if (k === "running") root.eeRunning = v === "1"
                else if (k === "bypass") root.eeOn = v.trim() !== "1"
                else if (k === "sink") root.sinkName = v
            })
            root.eePresets = presets
            root.eeEffects = effects
        }
    }

    Component.onCompleted: {
        refresh()
        if (vizActive && !cavaLaunched) cavaStart()
    }
    onExpandedChanged: if (root.expanded) root.refresh()
    // the desktop Effects card keeps itself up to date
    Timer {
        interval: 5000
        repeat: true
        running: root.onDesktop && root.cfg.deskFace === 3
        onTriggered: root.refresh()
    }

    // ---- small reusable bits -----------------------------------------
    component Chip: Rectangle {
        id: chip
        property alias text: label.text
        property string icon: ""
        implicitHeight: label.implicitHeight + 6
        implicitWidth: row.implicitWidth + 14
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(root.cText, 0.08)
        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4
            Kirigami.Icon {
                visible: chip.icon.length > 0
                source: chip.icon
                Layout.preferredWidth: Kirigami.Units.iconSizes.small - 4
                Layout.preferredHeight: Kirigami.Units.iconSizes.small - 4
            }
            PC3.Label {
                id: label
                font: Kirigami.Theme.smallFont
                opacity: 0.8
                elide: Text.ElideRight
                Layout.maximumWidth: 160
            }
        }
    }

    // ---- panel ---------------------------------------------------------
    // compactStyle: 0 cover, title and controls, 1 cover and title, 2 cover and controls
    compactRepresentation: MouseArea {
        id: compact
        readonly property int kind: root.cfg.compactStyle
        Layout.preferredWidth: kind === 2 ? compact.height * 4.2 : root.cfg.compactWidth
        Layout.minimumWidth: kind === 2 ? compact.height * 4.2 : root.cfg.compactWidth
        Layout.fillHeight: true
        hoverEnabled: true

        ArtProbe {
            source: root.cfg.accentFromArt ? root.artUrl : ""
            onHighlightChanged: root.artHighlight = highlight
        }
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton) root.player?.PlayPause()
            else root.expanded = !root.expanded
        }
        onWheel: function (wheel) {
            if (root.ready) root.player.changeVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05, true)
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Kirigami.Units.cornerRadius
            color: Qt.alpha(root.cAccent, compact.containsMouse || root.expanded ? 0.25 : 0)
            Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 4
            spacing: 6

            Item {
                Layout.preferredWidth: compact.height - 10
                Layout.preferredHeight: compact.height - 10
                Image {
                    id: miniArt
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    sourceSize.width: 128
                }
                Rectangle {
                    id: miniMask
                    anchors.fill: parent
                    radius: Kirigami.Units.cornerRadius
                    visible: false
                    layer.enabled: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: miniArt
                    maskEnabled: true
                    // soft cut: a hard 0 threshold leaves stair-stepped edges, worst on the spinning disc
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                    maskSource: miniMask
                    visible: root.artUrl.length > 0
                }
                Kirigami.Icon {
                    anchors.fill: parent
                    visible: root.artUrl.length === 0
                    source: "media-default-album"
                }
            }

            ColumnLayout {
                visible: compact.kind !== 2
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Math.max(10, compact.height * 0.3)
                    font.bold: true
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: root.ready && compact.height >= 30
                    text: root.fmtTime(root.position) + " / " + root.fmtTime(root.length)
                    font.pixelSize: Math.max(9, compact.height * 0.24)
                    font.features: { "tnum": 1 }
                    opacity: 0.7
                }
            }

            PC3.ToolButton {
                visible: root.ready && compact.kind !== 1
                icon.name: "media-skip-backward"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.Previous()
            }
            PC3.ToolButton {
                visible: root.ready && compact.kind !== 1
                icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.PlayPause()
            }
            PC3.ToolButton {
                visible: root.ready && compact.kind !== 1
                icon.name: "media-skip-forward"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.Next()
            }
        }
    }

    // ---- popup ---------------------------------------------------------
    fullRepresentation: Item {
        Layout.preferredWidth: root.onDesktop ? [230, 440, 280, 260, 360][root.cfg.deskFace] ?? 230 : Kirigami.Units.gridUnit * 27
        Layout.minimumWidth: root.onDesktop ? 150 : Kirigami.Units.gridUnit * 27
        Layout.preferredHeight: root.onDesktop ? [400, 150, 340, 340, 280][root.cfg.deskFace] ?? 400 : (view.item ? view.item.implicitHeight : 0)
        Layout.minimumHeight: root.onDesktop ? 110 : Layout.preferredHeight

        ArtProbe {
            source: root.cfg.accentFromArt ? root.artUrl : ""
            onHighlightChanged: root.artHighlight = highlight
        }

        // labels and controls follow the style's colors
        Kirigami.Theme.textColor: root.style.text
        Kirigami.Theme.highlightColor: root.style.accent

        Loader {
            id: view
            anchors.fill: parent
            sourceComponent: !root.onDesktop ? popupView
                : [albumCard, wideCard, vinylCard, effectsCard, visualizerCard][root.cfg.deskFace] ?? albumCard
        }
    }

    // ---- popup (panel) ---------------------------------------------------
    Component {
        id: popupView
        Item {
            id: full
            implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

            // faint blurred cover behind the theme's own popup background
            Image {
                id: bgArt
                anchors.fill: parent
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 256
                visible: false
            }
            Rectangle {
                id: bgMask
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 2
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: bgArt
                visible: root.artUrl.length > 0
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                maskEnabled: true
                // soft cut: a hard 0 threshold leaves stair-stepped edges, worst on the spinning disc
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
                maskSource: bgMask
                opacity: 0.22
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                // --- player switcher ---
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    visible: root.players.length > 1 || root.cfg.pinnedPlayer !== ""

                    PC3.ToolButton {
                        // the theme's tool buttons hug their text; give the chips some room
                        leftPadding: Kirigami.Units.largeSpacing
                        rightPadding: Kirigami.Units.largeSpacing
                        display: PC3.AbstractButton.TextBesideIcon
                        text: "Auto"
                        icon.name: "media-playlist-shuffle"
                        checkable: true
                        checked: root.pinned === null
                        onClicked: root.cfg.pinnedPlayer = ""
                        PC3.ToolTip.text: "Follow whichever player fits best"
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    Repeater {
                        model: root.players
                        PC3.ToolButton {
                            required property var modelData
                            // the theme's tool buttons hug their text; give the chips some room
                            leftPadding: Kirigami.Units.largeSpacing
                            rightPadding: Kirigami.Units.largeSpacing
                            display: PC3.AbstractButton.TextBesideIcon
                            text: modelData.identity
                            icon.name: root.isRemote(modelData) ? "smartphone"
                                : (modelData.iconName || modelData.desktopEntry || "media-playback-start")
                            checkable: true
                            checked: root.pinned === modelData
                            onClicked: root.cfg.pinnedPlayer = modelData.identity
                            PC3.ToolTip.text: (root.isPlaying(modelData) ? "Playing: " : "Paused: ")
                                + modelData.track + (modelData.artist ? " — " + modelData.artist : "")
                            PC3.ToolTip.visible: hovered
                            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }

                // --- now playing ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.gridUnit

                    Item {
                        id: disc
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 8
                        Layout.margins: 4

                        readonly property int kind: root.cfg.coverStyle   // 0 vinyl, 1 square, 2 round
                        Rectangle {
                            visible: disc.kind !== 1
                            anchors.centerIn: parent
                            width: parent.width + 10
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(root.cAccent, root.playing ? 0.9 : 0.35)
                            Behavior on border.color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                        }

                        Item {
                            id: spinner
                            anchors.fill: parent
                            Image {
                                id: discArt
                                anchors.fill: parent
                                source: root.artUrl
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 300
                                visible: false
                            }
                            Rectangle {
                                id: discMask
                                anchors.fill: parent
                                radius: disc.kind === 1 ? root.style.innerRadius * 1.5 : width / 2
                                visible: false
                                layer.enabled: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: discMask.radius
                                color: Qt.alpha(root.cText, 0.08)
                                visible: root.artUrl.length === 0
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.large
                                    height: width
                                    source: "media-default-album"
                                }
                            }
                            MultiEffect {
                                anchors.fill: parent
                                source: discArt
                                maskEnabled: true
                                // soft cut: a hard 0 threshold leaves stair-stepped edges, worst on the spinning disc
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0
                                maskSource: discMask
                                visible: root.artUrl.length > 0
                            }
                            // vinyl grooves
                            Repeater {
                                model: disc.kind === 0 ? 3 : 0
                                Rectangle {
                                    required property int index
                                    anchors.centerIn: parent
                                    width: spinner.width * (0.45 + index * 0.17)
                                    height: width
                                    radius: width / 2
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Qt.rgba(0, 0, 0, 0.18)
                                }
                            }
                            NumberAnimation on rotation {
                                from: 0; to: 360
                                duration: 14000
                                loops: Animation.Infinite
                                running: disc.kind === 0
                                paused: !root.playing
                            }
                        }
                        // spindle hole
                        Rectangle {
                            visible: disc.kind === 0
                            anchors.centerIn: parent
                            width: parent.width * 0.18
                            height: width
                            radius: width / 2
                            color: root.cBg
                            border.width: 2
                            border.color: Qt.alpha(root.cAccent, 0.8)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 3
                            text: root.title
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            visible: root.artist.length > 0
                            text: "by " + root.artist
                            opacity: 0.75
                            elide: Text.ElideRight
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Chip { visible: root.sinkName.length > 0; icon: "audio-headphones"; text: root.sinkName.replace(/ Analog Stereo$/, "") }
                            Chip { visible: root.source.length > 0; text: "via " + root.source }
                        }

                        PC3.Slider {
                            id: seek
                            Layout.fillWidth: true
                            from: 0
                            to: Math.max(1, root.length)
                            value: pressed ? value : root.position
                            enabled: root.ready && root.player.canSeek
                            onPressedChanged: if (!pressed) root.player.position = value
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: -Kirigami.Units.smallSpacing
                            PC3.Label { text: root.fmtTime(seek.pressed ? seek.value : root.position); font: Kirigami.Theme.smallFont; opacity: 0.7 }
                            Item { Layout.fillWidth: true }
                            PC3.Label { text: root.fmtTime(root.length); font: Kirigami.Theme.smallFont; opacity: 0.7 }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: Kirigami.Units.largeSpacing
                            PC3.ToolButton {
                                icon.name: "media-skip-backward"
                                enabled: root.ready && root.player.canGoPrevious
                                onClicked: root.player.Previous()
                            }
                            PC3.RoundButton {
                                icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                                icon.width: Kirigami.Units.iconSizes.medium
                                icon.height: Kirigami.Units.iconSizes.medium
                                highlighted: true
                                enabled: root.ready
                                onClicked: root.player.PlayPause()
                            }
                            PC3.ToolButton {
                                icon.name: "media-skip-forward"
                                enabled: root.ready && root.player.canGoNext
                                onClicked: root.player.Next()
                            }
                        }
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                // --- Easy Effects ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: "com.github.wwmm.easyeffects"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    }
                    Kirigami.Heading {
                        level: 4
                        text: "Easy Effects"
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        text: !root.eeRunning ? "not running"
                            : (root.eeOn ? root.eeCurrent : "bypassed")
                        color: root.eeOn && root.eeRunning ? root.cAccent : root.cMuted
                        elide: Text.ElideRight
                    }
                    PC3.Switch {
                        checked: root.eeOn && root.eeRunning
                        onToggled: root.setEffects(checked)
                        PC3.ToolTip.text: checked ? "Turn effects off (bypass)" : "Turn effects on"
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                    PC3.ToolButton {
                        icon.name: "configure"
                        onClicked: exec.run("bash '" + root.helper + "' open")
                        PC3.ToolTip.text: "Open Easy Effects"
                        PC3.ToolTip.visible: hovered
                        PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 4
                    rowSpacing: Kirigami.Units.smallSpacing
                    columnSpacing: Kirigami.Units.smallSpacing
                    enabled: root.eeOn
                    opacity: enabled ? 1 : 0.5
                    Repeater {
                        model: root.visibleGroups
                        PC3.Button {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1   // equal columns
                            text: modelData.label
                            checkable: true
                            checked: root.currentGroup !== null && root.currentGroup.base === modelData.base
                            onClicked: {
                                checked = Qt.binding(function () { return root.currentGroup !== null && root.currentGroup.base === modelData.base })
                                root.loadPreset(root.presetFor(modelData))
                            }
                            PC3.ToolTip.text: modelData.base
                            PC3.ToolTip.visible: hovered && contentItem.truncated === true
                            PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.currentGroup !== null && !!root.currentGroup.variants.min && !!root.currentGroup.variants.max
                    enabled: root.eeOn
                    PC3.Label { text: "Intensity"; opacity: 0.75 }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: ["min", "max"]
                        PC3.Button {
                            required property string modelData
                            text: modelData === "min" ? "Min" : "Max"
                            checkable: true
                            checked: root.currentVariant === modelData
                            onClicked: {
                                checked = Qt.binding(function () { return root.currentVariant === modelData })
                                root.cfg.variant = modelData
                                root.loadPreset(root.currentGroup.variants[modelData])
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- desktop cards ---------------------------------------------------
    // cover art clipped to a rounded rectangle or a circle
    component Art: Item {
        id: art
        property real radius: 0
        property bool showPlaceholder: true
        // a click on the cover brings the playing app to the front
        TapHandler { enabled: !!root.player && !!root.player.canRaise; onTapped: root.player.Raise() }
        HoverHandler { enabled: !!root.player && !!root.player.canRaise; cursorShape: Qt.PointingHandCursor }
        Image {
            id: artImage
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 512
            visible: false
        }
        Rectangle {
            id: artMask
            anchors.fill: parent
            radius: art.radius
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: artImage
            maskEnabled: true
            // soft cut: a hard 0 threshold leaves stair-stepped edges, worst on the spinning disc
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: artMask
            visible: root.artUrl.length > 0
        }
        Rectangle {
            anchors.fill: parent
            radius: art.radius
            visible: art.showPlaceholder && root.artUrl.length === 0
            color: root.style.card
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.4
                height: width
                source: "media-default-album"
            }
        }
    }

    component TransportButton: PC3.AbstractButton {
        id: sb
        property string iconName
        property real size
        property bool onArt
        Layout.preferredWidth: sb.size * 1.25
        Layout.preferredHeight: sb.size
        hoverEnabled: true
        background: Rectangle {
            radius: root.style.innerRadius
            color: sb.onArt ? Qt.rgba(0, 0, 0, sb.hovered ? 0.5 : 0.35)
                            : (sb.hovered ? root.style.cardHover : root.style.card)
            border.color: sb.onArt ? Qt.rgba(1, 1, 1, 0.12) : root.style.cardEdge
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: sb.size * 0.5
                height: width
                source: sb.iconName
                isMask: true
                color: sb.onArt ? "white" : root.cText
            }
        }
    }

    // previous / play / next; the play button is a filled accent pill
    component Transport: RowLayout {
        id: tr
        property real size: Kirigami.Units.gridUnit * 2.2
        property bool onArt: false     // drawn over the cover: frosted buttons
        spacing: size * 0.25
        TransportButton {
            size: tr.size
            onArt: tr.onArt
            iconName: "media-skip-backward"
            enabled: root.ready && root.player.canGoPrevious
            onClicked: root.player.Previous()
        }
        PC3.AbstractButton {
            id: playButton
            Layout.preferredWidth: tr.size * 1.6
            Layout.preferredHeight: tr.size
            enabled: root.ready
            hoverEnabled: true
            onClicked: root.player.PlayPause()
            background: Rectangle {
                radius: root.style.innerRadius
                color: playButton.hovered ? Qt.lighter(root.cAccent, 1.12) : root.cAccent
            }
            contentItem: Item {
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: tr.size * 0.55
                    height: width
                    source: root.playing ? "media-playback-pause" : "media-playback-start"
                    isMask: true
                    color: root.style.accentInk
                }
            }
        }
        TransportButton {
            size: tr.size
            onArt: tr.onArt
            iconName: "media-skip-forward"
            enabled: root.ready && root.player.canGoNext
            onClicked: root.player.Next()
        }
    }

    component SeekBar: Item {
        implicitHeight: Math.max(4, Kirigami.Units.gridUnit * 0.25)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.style.track
            Rectangle {
                width: parent.width * Math.min(1, root.position / Math.max(1, root.length))
                height: parent.height
                radius: parent.radius
                color: root.cAccent
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            enabled: root.ready && root.player.canSeek
            onClicked: function (mouse) { root.player.position = root.length * Math.max(0, Math.min(1, (mouse.x - 6) / (width - 12))) }
        }
    }

    // a desktop card: styled surface plus content, with optional text shadow
    component DeskCard: Item {
        default property alias content: inner.data
        readonly property real pad: Math.max(Kirigami.Units.largeSpacing * 1.5, root.style.radius * 0.6)
        NyxSurface {
            anchors.fill: parent
            style: root.style
        }
        Item {
            id: inner
            anchors.fill: parent
            layer.enabled: root.style.textShadow > 0
            layer.effect: NyxTextShadow { style: root.style }
        }
    }

    // 0: album: the cover fills the card, title over it, controls at the bottom
    Component {
        id: albumCard
        DeskCard {
            id: card
            Art {
                id: cover
                anchors.fill: parent
                anchors.margins: root.style.border > 0 ? 1 : 0
                radius: Math.max(0, root.style.radius - anchors.margins)
            }
            // darken top and bottom so the text stays readable on any cover
            Rectangle {
                anchors.fill: cover
                radius: cover.radius
                visible: root.artUrl.length > 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
                    GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.6) }
                }
            }
            ColumnLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: card.pad }
                spacing: Kirigami.Units.smallSpacing
                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.artUrl.length > 0 ? "white" : root.cText
                    font.family: root.style.font || Kirigami.Theme.defaultFont.family
                    font.pixelSize: Math.min(card.width * 0.13, Kirigami.Units.gridUnit * 2.2)
                    font.weight: Font.Black
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    lineHeight: 0.9
                }
                Rectangle {
                    visible: root.artist.length > 0
                    implicitWidth: Math.min(card.width - card.pad * 2, artistLabel.implicitWidth + Kirigami.Units.largeSpacing * 2)
                    implicitHeight: artistLabel.implicitHeight + Kirigami.Units.smallSpacing * 1.5
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.18)
                    Text {
                        id: artistLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - Kirigami.Units.largeSpacing * 2)
                        text: root.artist
                        color: root.artUrl.length > 0 ? "white" : root.cText
                        elide: Text.ElideRight
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        font.weight: Font.DemiBold
                    }
                }
            }
            ColumnLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: card.pad }
                spacing: Kirigami.Units.largeSpacing
                SeekBar { Layout.fillWidth: true; visible: root.ready }
                Transport {
                    Layout.alignment: Qt.AlignHCenter
                    size: Math.min(Kirigami.Units.gridUnit * 2.4, card.width / 6)
                    onArt: root.artUrl.length > 0
                }
            }
        }
    }

    // 1: wide: cover on the left, title, seek bar and controls on the right
    Component {
        id: wideCard
        DeskCard {
            id: card
            RowLayout {
                anchors.fill: parent
                anchors.margins: card.pad * 0.75
                spacing: card.pad
                Art {
                    Layout.preferredHeight: parent.height
                    Layout.preferredWidth: parent.height
                    radius: root.style.innerRadius * 1.3
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Label {
                        Layout.fillWidth: true
                        text: root.title
                        font.pixelSize: Math.min(card.height * 0.16, Kirigami.Units.gridUnit * 1.3)
                        font.bold: true
                        font.family: root.style.font || Kirigami.Theme.defaultFont.family
                        elide: Text.ElideRight
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        visible: root.artist.length > 0
                        text: root.artist + (root.source.length > 0 ? "  ·  " + root.source : "")
                        color: root.style.dim
                        elide: Text.ElideRight
                    }
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        PC3.Label { text: root.fmtTime(root.position); font: Kirigami.Theme.smallFont; color: root.style.dim }
                        SeekBar { Layout.fillWidth: true }
                        PC3.Label { text: root.fmtTime(root.length); font: Kirigami.Theme.smallFont; color: root.style.dim }
                    }
                    Transport {
                        Layout.alignment: Qt.AlignLeft
                        size: Math.min(Kirigami.Units.gridUnit * 2, card.height * 0.22)
                    }
                }
            }
        }
    }

    // 2: vinyl: the spinning record with title and controls under it
    Component {
        id: vinylCard
        DeskCard {
            id: card
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: card.pad
                spacing: Kirigami.Units.largeSpacing
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Item {
                        id: record
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#111"
                        }
                        Art {
                            anchors.fill: parent
                            anchors.margins: parent.width * 0.04
                            radius: width / 2
                        }
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.centerIn: parent
                                width: record.width * (0.4 + index * 0.17)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.22)
                            }
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width * 0.16
                            height: width
                            radius: width / 2
                            color: "#111"
                            border.width: 2
                            border.color: root.cAccent
                        }
                        NumberAnimation on rotation {
                            from: 0; to: 360
                            duration: 14000
                            loops: Animation.Infinite
                            running: true
                            paused: !root.playing
                        }
                    }
                }
                PC3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.title
                    font.bold: true
                    font.pixelSize: Kirigami.Units.gridUnit * 1.05
                    font.family: root.style.font || Kirigami.Theme.defaultFont.family
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    Layout.topMargin: -Kirigami.Units.smallSpacing
                    visible: root.artist.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.artist
                    color: root.style.dim
                    elide: Text.ElideRight
                }
                Transport {
                    Layout.alignment: Qt.AlignHCenter
                    size: Math.min(Kirigami.Units.gridUnit * 2.2, card.width / 6)
                }
            }
        }
    }

    // 3: effects: the Easy Effects preset, its effects, and quick switching
    Component {
        id: effectsCard
        DeskCard {
            id: card
            component Pill: Rectangle {
                property alias text: pillLabel.text
                property string icon
                implicitWidth: pillRow.implicitWidth + Kirigami.Units.largeSpacing * 1.5
                implicitHeight: pillLabel.implicitHeight + Kirigami.Units.smallSpacing * 1.5
                radius: height / 2
                color: root.style.card
                border.color: root.style.cardEdge
                RowLayout {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        visible: parent.parent.icon.length > 0
                        source: parent.parent.icon
                        Layout.preferredWidth: Kirigami.Units.iconSizes.small - 4
                        Layout.preferredHeight: Kirigami.Units.iconSizes.small - 4
                    }
                    PC3.Label {
                        id: pillLabel
                        font: Kirigami.Theme.smallFont
                        color: root.style.dim
                    }
                }
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: card.pad
                spacing: Kirigami.Units.largeSpacing
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    Pill { visible: root.sinkName.length > 0; icon: "audio-headphones"; text: root.sinkName.replace(/ Analog Stereo$/, "") }
                    Pill { text: !root.eeRunning ? "Not running" : (root.eeOn ? (root.playing ? "Playing now" : "Ready") : "Bypassed") }
                }
                // big icon badge; arrows step through presets
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    PC3.ToolButton {
                        icon.name: "go-previous"
                        enabled: root.visibleGroups.length > 1
                        onClicked: root.stepPreset(-1)
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.8
                            height: width
                            radius: width * 0.3
                            rotation: 45
                            color: root.eeOn && root.eeRunning ? root.cAccent : root.style.card
                            Behavior on color { ColorAnimation { duration: Kirigami.Units.longDuration } }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height) * 0.4
                            height: width
                            source: "audio-volume-high"
                            isMask: true
                            color: root.eeOn && root.eeRunning ? root.style.accentInk : root.cText
                        }
                    }
                    PC3.ToolButton {
                        icon.name: "go-next"
                        enabled: root.visibleGroups.length > 1
                        onClicked: root.stepPreset(1)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.currentGroup ? root.currentGroup.label : (root.eeCurrent || "No preset")
                    color: root.cText
                    font.family: root.style.font || Kirigami.Theme.defaultFont.family
                    font.pixelSize: Math.min(card.width * 0.13, Kirigami.Units.gridUnit * 2)
                    font.weight: Font.Black
                    elide: Text.ElideRight
                }
                Flow {
                    Layout.fillWidth: true
                    visible: root.eeEffects.length > 0
                    spacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.eeEffects.slice(0, 6)
                        Pill { required property string modelData; text: root.effectLabel(modelData) }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PC3.AbstractButton {
                        id: editButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.9
                        hoverEnabled: true
                        onClicked: exec.run("bash '" + root.helper + "' open")
                        background: Rectangle {
                            radius: height / 2
                            color: editButton.hovered ? Qt.lighter(root.cAccent, 1.12) : root.cAccent
                        }
                        contentItem: PC3.Label {
                            text: "Edit effects"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            color: root.style.accentInk
                            font.bold: true
                        }
                    }
                    PC3.AbstractButton {
                        id: bypassButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.9
                        hoverEnabled: true
                        onClicked: root.setEffects(!root.eeOn)
                        background: Rectangle {
                            radius: height / 2
                            color: !root.eeOn ? root.style.active : (bypassButton.hovered ? root.style.cardHover : root.style.card)
                            border.color: !root.eeOn ? root.style.activeEdge : root.style.cardEdge
                        }
                        contentItem: PC3.Label {
                            text: root.eeOn ? "Bypass" : "Bypassed"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    // 4: visualizer: cover and title on top, audio bars from cava, controls at the bottom
    Component {
        id: visualizerCard
        DeskCard {
            id: card
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: card.pad
                spacing: Kirigami.Units.largeSpacing
                RowLayout {
                    visible: root.cfg.vizShowInfo
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing
                    Art {
                        readonly property real side: Math.min(Kirigami.Units.gridUnit * 3.5, card.height * 0.22)
                        Layout.preferredWidth: side
                        Layout.preferredHeight: side
                        radius: root.style.innerRadius
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        PC3.Label {
                            Layout.fillWidth: true
                            text: root.title
                            font.bold: true
                            font.pixelSize: Math.min(card.width * 0.06, Kirigami.Units.gridUnit * 1.2)
                            font.family: root.style.font || Kirigami.Theme.defaultFont.family
                            color: root.style.text
                            elide: Text.ElideRight
                        }
                        PC3.Label {
                            Layout.fillWidth: true
                            visible: root.artist.length > 0
                            text: root.artist
                            color: root.style.dim
                            elide: Text.ElideRight
                        }
                    }
                }
                // audio bars growing from the middle; flat when paused or without cava
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Row {
                        id: bars
                        anchors.fill: parent
                        visible: !(root.cavaChecked && !root.cavaOk)
                        readonly property real gapRatio: Math.max(0, Math.min(100, root.cfg.vizGap)) / 100
                        readonly property real barW: width / ((1 + gapRatio) * root.vizBars - gapRatio)
                        readonly property int shape: root.cfg.vizShape     // 0 mirrored, 1 bottom, 2 top
                        readonly property real minH: Math.min(barW * 0.5, 6)
                        readonly property real barRadius: barW / 2 * Math.max(0, Math.min(100, root.cfg.vizRound)) / 100
                        readonly property bool live: root.levels.length > 0
                        readonly property color base: root.cfg.vizColorMode === 0 ? root.cAccent : root.cfg.vizColor
                        readonly property color tip: root.cfg.vizColorMode === 2 ? root.cfg.vizColor2 : base
                        spacing: barW * gapRatio
                        Repeater {
                            model: root.vizBars
                            Item {
                                id: slot
                                required property int index
                                width: bars.barW
                                height: bars.height
                                // places a bar or peak marker of height h for the chosen shape
                                function yFor(h) { return bars.shape === 0 ? (height - h) / 2 : bars.shape === 1 ? height - h : 0 }
                                Rectangle {
                                    readonly property real h: Math.max(bars.minH, slot.height * Math.min(100, root.levels[slot.index] || 0) / 100)
                                    y: slot.yFor(h)
                                    width: parent.width
                                    height: h
                                    radius: bars.barRadius
                                    color: bars.live ? bars.base : root.style.track
                                    // vertical gradient from the base of the bar to its tip(s)
                                    gradient: bars.live && root.cfg.vizColorMode === 2 ? grad : null
                                    Gradient {
                                        id: grad
                                        GradientStop { position: 0; color: bars.shape === 2 ? bars.base : bars.tip }
                                        GradientStop { position: 0.5; color: bars.shape === 0 ? bars.base : Qt.tint(bars.base, Qt.alpha(bars.tip, 0.5)) }
                                        GradientStop { position: 1; color: bars.shape === 1 ? bars.base : bars.tip }
                                    }
                                    // no height animation: it would redraw the desktop at the screen's
                                    // refresh rate (300 Hz) for as long as music plays; cava already
                                    // smooths the bars, so they only repaint when new levels arrive
                                }
                                // peak marker: for mirrored bars, one above and one below
                                Repeater {
                                    model: root.cfg.vizPeaks && bars.live ? (bars.shape === 0 ? 2 : 1) : 0
                                    Rectangle {
                                        required property int index
                                        readonly property real ph: slot.height * Math.min(100, root.peaks[slot.index] || 0) / 100
                                        readonly property real t: Math.max(2, Math.min(bars.barW * 0.35, 4))
                                        width: slot.width
                                        height: t
                                        radius: Math.min(bars.barRadius, t / 2)
                                        color: bars.tip
                                        visible: ph > bars.minH + t
                                        y: bars.shape === 0 ? (index === 0 ? (slot.height - ph) / 2 - t - 1 : (slot.height + ph) / 2 + 1)
                                          : bars.shape === 1 ? slot.height - ph - t - 1 : ph + 1
                                    }
                                }
                            }
                        }
                    }
                    PC3.Label {
                        anchors.centerIn: parent
                        width: parent.width
                        visible: root.cavaChecked && !root.cavaOk
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Install cava to see the audio bars"
                        color: root.style.faint
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label { text: root.fmtTime(root.position); font: Kirigami.Theme.smallFont; color: root.style.dim }
                    SeekBar { Layout.fillWidth: true }
                    PC3.Label { text: root.fmtTime(root.length); font: Kirigami.Theme.smallFont; color: root.style.dim }
                }
                Transport {
                    Layout.alignment: Qt.AlignHCenter
                    size: Math.min(Kirigami.Units.gridUnit * 2.2, card.width / 7)
                }
            }
        }
    }
}
