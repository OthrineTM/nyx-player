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

PlasmoidItem {
    id: root

    // all colors come from the active Plasma/KDE theme
    readonly property color cAccent: Kirigami.Theme.highlightColor
    readonly property color cText: Kirigami.Theme.textColor
    readonly property color cMuted: Kirigami.Theme.disabledTextColor
    readonly property color cBg: Kirigami.Theme.backgroundColor

    readonly property var cfg: Plasmoid.configuration
    readonly property string helper: Qt.resolvedUrl("../code/ee.sh").toString().replace("file://", "")

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Prefer This Computer's Players"
            icon.name: "computer"
            checkable: true
            checked: root.cfg.preferLocal
            onTriggered: root.cfg.preferLocal = checked
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
    // Plasma's current player can be an idle app (e.g. an Electron app with no media),
    // so rank: playing local > playing remote > paused local > paused remote.
    readonly property var player: {
        var cur = mpris.currentPlayer
        var best = null, bestRank = -1
        var cands = [cur]
        for (var i = 0; i < allPlayers.count; i++) {
            var o = allPlayers.objectAt(i)
            cands.push(o ? o.container : null)
        }
        for (var j = 0; j < cands.length; j++) {
            var p = cands[j]
            if (!hasMeta(p)) continue
            var rank = (isPlaying(p) ? 2 : 0) + (cfg.preferLocal && isRemote(p) ? 0 : 1)
            if (rank > bestRank) { best = p; bestRank = rank }
        }
        return best || cur
    }
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

    // ---- Easy Effects -------------------------------------------------
    property var eePresets: []       // raw preset names
    property string eeCurrent: ""
    property bool eeRunning: false
    property bool eeOn: true
    property string sinkName: ""

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
            var presets = []
            ;(data["stdout"] || "").split("\n").forEach(function (line) {
                var i = line.indexOf("=")
                if (i < 0) return
                var k = line.slice(0, i), v = line.slice(i + 1)
                if (k === "preset") presets.push(v)
                else if (k === "current") root.eeCurrent = v
                else if (k === "running") root.eeRunning = v === "1"
                else if (k === "bypass") root.eeOn = v.trim() !== "1"
                else if (k === "sink") root.sinkName = v
            })
            root.eePresets = presets
        }
    }

    Component.onCompleted: refresh()
    onExpandedChanged: if (root.expanded) root.refresh()

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
    compactRepresentation: MouseArea {
        id: compact
        Layout.preferredWidth: root.cfg.compactWidth
        Layout.minimumWidth: root.cfg.compactWidth
        Layout.fillHeight: true
        hoverEnabled: true
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
                visible: root.ready
                icon.name: "media-skip-backward"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.Previous()
            }
            PC3.ToolButton {
                visible: root.ready
                icon.name: root.playing ? "media-playback-pause" : "media-playback-start"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.PlayPause()
            }
            PC3.ToolButton {
                visible: root.ready
                icon.name: "media-skip-forward"
                Layout.preferredWidth: compact.height - 6
                Layout.preferredHeight: compact.height - 6
                onClicked: root.player.Next()
            }
        }
    }

    // ---- popup ---------------------------------------------------------
    fullRepresentation: Item {
        id: full
        Layout.preferredWidth: Kirigami.Units.gridUnit * 27
        Layout.minimumWidth: Kirigami.Units.gridUnit * 27
        Layout.preferredHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2
        Layout.minimumHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

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
            maskSource: bgMask
            opacity: 0.22
        }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // --- now playing ---
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit

                Item {
                    id: disc
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 8
                    Layout.margins: 4

                    Rectangle {
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
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
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
                            maskSource: discMask
                            visible: root.artUrl.length > 0
                        }
                        // vinyl grooves
                        Repeater {
                            model: 3
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
                            running: true
                            paused: !root.playing
                        }
                    }
                    // spindle hole
                    Rectangle {
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
                    model: root.eeGroups
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
