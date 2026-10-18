import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    id: page

    property var cfg_hiddenPresets: []

    readonly property string helper: Qt.resolvedUrl("../code/ee.sh").toString().replace("file://", "")
    // preset groups as the popup shows them: "rock-min" and "rock-max" are one entry, "rock"
    property var groups: []

    function isHidden(base) { return (cfg_hiddenPresets || []).indexOf(base) >= 0 }
    function setHidden(base, hide) {
        var list = (cfg_hiddenPresets || []).filter(function (b) { return b !== base })
        if (hide) list.push(base)
        cfg_hiddenPresets = list
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: ["bash '" + page.helper + "' state"]
        onNewData: function (source, data) {
            disconnectSource(source)
            var seen = {}, out = []
            ;(data["stdout"] || "").split("\n").forEach(function (line) {
                if (line.indexOf("preset=") !== 0) return
                var m = line.slice(7).match(/^(.*)-(min|max)$/)
                var base = m ? m[1] : line.slice(7)
                if (!seen[base]) { seen[base] = true; out.push(base) }
            })
            page.groups = out
        }
    }

    Kirigami.FormLayout {
        QQC2.Label {
            Kirigami.FormData.label: "Easy Effects presets:"
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Untick the presets you don't want as buttons in the popup. Hidden presets stay in Easy Effects."
        }
        RowLayout {
            QQC2.Button {
                text: "Show all"
                icon.name: "view-visible"
                onClicked: page.cfg_hiddenPresets = []
            }
            QQC2.Button {
                text: "Hide all"
                icon.name: "view-hidden"
                onClicked: page.cfg_hiddenPresets = page.groups.slice()
            }
        }
        QQC2.Label {
            visible: page.groups.length === 0
            text: "No presets found in ~/.local/share/easyeffects/output"
            opacity: 0.7
        }
        Repeater {
            model: page.groups
            QQC2.CheckBox {
                required property string modelData
                text: modelData
                checked: !page.isHidden(modelData)
                onToggled: page.setHidden(modelData, !checked)
            }
        }
    }
}
