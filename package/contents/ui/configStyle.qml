import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQC
import org.kde.plasma.plasma5support as P5Support
import "NyxPresets.js" as Presets

// "Style" settings page, the same in every Nyx widget
KCM.SimpleKCM {
    id: page

    property bool cfg_styleShared
    property string cfg_stylePreset
    property string cfg_styleTint
    property int cfg_styleOpacity
    property int cfg_styleBorder
    property bool cfg_styleBorderAccent
    property int cfg_styleRadius
    property int cfg_styleSheen
    property int cfg_styleShadow
    property int cfg_styleGlow
    property int cfg_styleTextShadow
    property string cfg_styleText
    property string cfg_styleAccent
    property string cfg_styleFont
    property string cfg_styleCard
    property int cfg_styleSpace
    property int cfg_styleWeight
    property bool cfg_styleCaps
    property string cfg_styleNumFont
    property int cfg_styleMotion
    property string cfg_styleSubText
    property int cfg_styleSubStrength
    property bool cfg_styleAutoContrast

    property var userPresets: []

    // the look being edited, as a config-like object for the preview
    readonly property var editCfg: ({
        styleShared: false, stylePreset: cfg_stylePreset, styleTint: cfg_styleTint,
        styleOpacity: cfg_styleOpacity, styleBorder: cfg_styleBorder, styleBorderAccent: cfg_styleBorderAccent,
        styleRadius: cfg_styleRadius, styleSheen: cfg_styleSheen, styleShadow: cfg_styleShadow,
        styleGlow: cfg_styleGlow, styleTextShadow: cfg_styleTextShadow, styleText: cfg_styleText,
        styleAccent: cfg_styleAccent, styleFont: cfg_styleFont,
        styleCard: cfg_styleCard, styleSpace: cfg_styleSpace, styleWeight: cfg_styleWeight,
        styleCaps: cfg_styleCaps, styleNumFont: cfg_styleNumFont, styleMotion: cfg_styleMotion,
        styleSubText: cfg_styleSubText, styleSubStrength: cfg_styleSubStrength, styleAutoContrast: cfg_styleAutoContrast
    })

    function loadLook(l) {
        Presets.keys.forEach(function (k) { if (l[k] !== undefined) page["cfg_" + Presets.cfgKey(k)] = l[k] })
    }
    // any tweak turns the look into a custom one
    function tweak(key, value) {
        page["cfg_" + key] = value
        page.cfg_stylePreset = "custom"
    }
    function currentLook() { return Presets.fromConfig(editCfg) }

    function savePreset(name) {
        var look = currentLook()
        look.preset = "user-" + Date.now()
        look.name = name
        var list = userPresets.filter(function (p) { return p.name !== name })
        list.push(look)
        userPresets = list
        page.cfg_stylePreset = look.preset
        exec.run(Presets.writeCommand("presets.json", JSON.stringify(list), Qt.btoa))
    }
    function deletePreset(id) {
        userPresets = userPresets.filter(function (p) { return p.preset !== id })
        exec.run(Presets.writeCommand("presets.json", JSON.stringify(userPresets), Qt.btoa))
    }

    // called by Plasma when the settings are applied: publish the look to the other widgets
    function saveConfig() {
        if (cfg_styleShared)
            exec.run(Presets.writeCommand("style.json", Presets.serialize(currentLook()), Qt.btoa))
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        function run(cmd) { connectSource(cmd) }
        onNewData: function (source, data) {
            disconnectSource(source)
            var out = (data["stdout"] || "").trim()
            if (source === Presets.readPresetsCommand) {
                try { page.userPresets = out.length > 0 ? JSON.parse(out) : [] } catch (e) { page.userPresets = [] }
            } else if (source === Presets.readStyleCommand && out.length > 0 && page.cfg_styleShared) {
                // edit the shared look, not this widget's old local copy
                try { page.loadLook(JSON.parse(out)) } catch (e) {}
            }
        }
    }
    Component.onCompleted: {
        exec.run(Presets.readPresetsCommand)
        exec.run(Presets.readStyleCommand)
    }

    // color button with a "theme" reset; empty value = follow the Plasma theme
    component ThemedColor: RowLayout {
        id: tc
        property string value
        property color fallback
        property string resetText: "Theme"
        signal picked(string c)
        QQC2.CheckBox {
            text: tc.resetText
            checked: tc.value === ""
            onToggled: tc.picked(checked ? "" : tc.fallback.toString())
        }
        KQC.ColorButton {
            id: btn
            enabled: tc.value !== ""
            color: tc.value !== "" ? tc.value : tc.fallback
            showAlphaChannel: false
            onAccepted: function (c) {
                tc.picked(c.toString())
                btn.color = Qt.binding(function () { return tc.value !== "" ? tc.value : tc.fallback })
            }
        }
    }

    // a font picker that shows every font name in that font
    component FontCombo: QQC2.ComboBox {
        id: fc
        property string value
        property string emptyText
        signal picked(string family)
        Layout.preferredWidth: Kirigami.Units.gridUnit * 14
        displayText: value === "" ? emptyText : value
        currentIndex: Math.max(0, model.indexOf(value))
        onActivated: function (i) { fc.picked(model[i]) }
        font.family: value || Kirigami.Theme.defaultFont.family
        delegate: QQC2.ItemDelegate {
            required property var modelData
            required property int index
            width: ListView.view ? ListView.view.width : implicitWidth
            highlighted: fc.highlightedIndex === index
            contentItem: QQC2.Label {
                text: modelData === "" ? fc.emptyText : modelData
                font.family: modelData || Kirigami.Theme.defaultFont.family
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    component Tweak: RowLayout {
        id: tw
        property alias from: sl.from
        property alias to: sl.to
        property int value
        property string suffix: " %"
        signal moved(int v)
        QQC2.Slider {
            id: sl
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            stepSize: 1
            value: tw.value
            onMoved: tw.moved(Math.round(value))
        }
        QQC2.Label {
            text: tw.value + tw.suffix
            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.5
            font.features: { "tnum": 1 }
        }
    }

    Kirigami.FormLayout {
        // ---- live preview ----
        Item {
            Kirigami.FormData.label: "Preview:"
            // FormLayout sizes plain Items by their implicit size, so set it as well as the layout hints
            implicitWidth: Kirigami.Units.gridUnit * 22
            implicitHeight: Kirigami.Units.gridUnit * 8
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            Layout.minimumWidth: implicitWidth
            Layout.minimumHeight: implicitHeight

            // a busy backdrop, so transparency is easy to judge
            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.cornerRadius * 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#3b1d6e" }
                    GradientStop { position: 0.5; color: "#c2417a" }
                    GradientStop { position: 1.0; color: "#f2a65a" }
                }
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        x: parent.width * (0.1 + index * 0.19); y: parent.height * (index % 2 ? 0.15 : 0.55)
                        width: parent.height * 0.4; height: width; radius: width / 2
                        color: Qt.rgba(1, 1, 1, 0.35)
                    }
                }
            }
            NyxStyle {
                id: preview
                cfg: page.editCfg
                themeText: Kirigami.Theme.textColor
                themeAccent: Kirigami.Theme.highlightColor
                themeBackground: Kirigami.Theme.backgroundColor
            }
            NyxSurface {
                id: sample
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: parent.height * 0.72
                style: preview
            }
            ColumnLayout {
                anchors.fill: sample
                anchors.margins: Kirigami.Units.largeSpacing * 1.5
                spacing: 0
                layer.enabled: preview.textShadow > 0
                layer.effect: NyxTextShadow { style: preview }
                Text {
                    text: preview.label(preview.presetName)
                    color: preview.faint
                    font.family: preview.font || Kirigami.Theme.defaultFont.family
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.weight: preview.labelWeight
                    font.letterSpacing: Kirigami.Theme.smallFont.pixelSize * preview.tracking
                }
                Text {
                    text: Qt.formatTime(new Date(), "hh:mm")
                    color: preview.text
                    font.family: preview.numberFont || Kirigami.Theme.defaultFont.family
                    font.pixelSize: sample.height * 0.34
                    font.weight: preview.numberWeight
                }
                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * preview.space
                    Repeater {
                        model: ["Mon", "Tue", "Wed"]
                        Item {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.gridUnit * 1.4
                            HoverHandler { id: chipHover }
                            NyxCard {
                                anchors.fill: parent
                                style: preview
                                hovered: chipHover.hovered
                                highlighted: parent.index === 0
                            }
                            Text {
                                anchors.centerIn: parent
                                text: preview.label(parent.modelData)
                                color: preview.text
                                font.family: preview.font || Kirigami.Theme.defaultFont.family
                                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                font.weight: preview.labelWeight
                                font.letterSpacing: Kirigami.Theme.smallFont.pixelSize * preview.tracking
                            }
                        }
                    }
                }
            }
        }

        QQC2.CheckBox {
            Kirigami.FormData.label: "All widgets:"
            text: "Share this look with every Nyx widget"
            checked: page.cfg_styleShared
            onToggled: page.cfg_styleShared = checked
        }

        // ---- presets ----
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Presets" }

        Item {
            Kirigami.FormData.label: "Built-in:"
            // FormLayout sizes items by their implicit size, and a Flow's is one button wide
            implicitWidth: Kirigami.Units.gridUnit * 26
            implicitHeight: builtinFlow.implicitHeight
            Flow {
                id: builtinFlow
                width: parent.width
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: Presets.builtin
                    QQC2.Button {
                        required property var modelData
                        text: modelData.name
                        highlighted: page.cfg_stylePreset === modelData.preset
                        onClicked: page.loadLook(modelData)
                    }
                }
            }
        }
        Item {
            Kirigami.FormData.label: "Yours:"
            visible: page.userPresets.length > 0
            // FormLayout sizes items by their implicit size, and a Flow's is one button wide
            implicitWidth: Kirigami.Units.gridUnit * 26
            implicitHeight: userFlow.implicitHeight
            Flow {
                id: userFlow
                width: parent.width
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: page.userPresets
                    QQC2.Button {
                        required property var modelData
                        text: modelData.name
                        highlighted: page.cfg_stylePreset === modelData.preset
                        onClicked: page.loadLook(modelData)
                        QQC2.ToolButton {
                            anchors { right: parent.right; top: parent.top; margins: -Kirigami.Units.smallSpacing }
                            width: Kirigami.Units.iconSizes.small + 4; height: width
                            icon.name: "edit-delete-remove"
                            icon.width: Kirigami.Units.iconSizes.small; icon.height: Kirigami.Units.iconSizes.small
                            onClicked: page.deletePreset(parent.modelData.preset)
                            QQC2.ToolTip.text: "Delete this preset"
                            QQC2.ToolTip.visible: hovered
                        }
                    }
                }
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Save the current look:"
            QQC2.TextField { id: presetName; placeholderText: "Preset name" }
            QQC2.Button {
                text: "Save"
                icon.name: "document-save"
                enabled: presetName.text.trim().length > 0
                onClicked: { page.savePreset(presetName.text.trim()); presetName.text = "" }
            }
        }

        // ---- tweaks ----
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Surface" }

        ThemedColor {
            Kirigami.FormData.label: "Tint:"
            value: page.cfg_styleTint
            fallback: Kirigami.Theme.textColor
            onPicked: c => page.tweak("styleTint", c)
        }
        Tweak { Kirigami.FormData.label: "Opacity:"; from: 0; to: 100; value: page.cfg_styleOpacity; onMoved: v => page.tweak("styleOpacity", v) }
        Tweak { Kirigami.FormData.label: "Shine:"; from: 0; to: 100; value: page.cfg_styleSheen; onMoved: v => page.tweak("styleSheen", v) }
        Tweak { Kirigami.FormData.label: "Corner radius:"; from: 0; to: 40; suffix: " px"; value: page.cfg_styleRadius; onMoved: v => page.tweak("styleRadius", v) }
        Tweak { Kirigami.FormData.label: "Edge:"; from: 0; to: 100; value: page.cfg_styleBorder; onMoved: v => page.tweak("styleBorder", v) }
        QQC2.CheckBox {
            text: "Edge in the accent color"
            checked: page.cfg_styleBorderAccent
            onToggled: page.tweak("styleBorderAccent", checked)
        }
        Tweak { Kirigami.FormData.label: "Shadow:"; from: 0; to: 100; value: page.cfg_styleShadow; onMoved: v => page.tweak("styleShadow", v) }
        Tweak { Kirigami.FormData.label: "Accent glow:"; from: 0; to: 100; value: page.cfg_styleGlow; onMoved: v => page.tweak("styleGlow", v) }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Text" }

        ThemedColor {
            Kirigami.FormData.label: "Text color:"
            value: page.cfg_styleText
            fallback: Kirigami.Theme.textColor
            onPicked: c => page.tweak("styleText", c)
        }
        ThemedColor {
            Kirigami.FormData.label: "Accent:"
            value: page.cfg_styleAccent
            fallback: Kirigami.Theme.highlightColor
            onPicked: c => page.tweak("styleAccent", c)
        }
        ThemedColor {
            Kirigami.FormData.label: "Secondary text:"
            resetText: "Same as text"
            value: page.cfg_styleSubText
            fallback: page.cfg_styleText !== "" ? page.cfg_styleText : Kirigami.Theme.textColor
            onPicked: c => page.tweak("styleSubText", c)
        }
        Tweak {
            Kirigami.FormData.label: "Secondary text strength:"
            from: 20; to: 100
            value: page.cfg_styleSubStrength
            onMoved: v => page.tweak("styleSubStrength", v)
        }
        Tweak { Kirigami.FormData.label: "Text shadow:"; from: 0; to: 100; value: page.cfg_styleTextShadow; onMoved: v => page.tweak("styleTextShadow", v) }
        QQC2.CheckBox {
            Kirigami.FormData.label: "Readability:"
            text: "Fix hard-to-read colors automatically"
            checked: page.cfg_styleAutoContrast
            onToggled: page.tweak("styleAutoContrast", checked)
        }
        QQC2.Label {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Swaps text that would blend into the background for dark or light text, and keeps text on the wallpaper strong. Turn it off to use exactly the colors above."
        }
        FontCombo {
            Kirigami.FormData.label: "Font:"
            model: [""].concat(Qt.fontFamilies())
            value: page.cfg_styleFont
            emptyText: "Theme font"
            onPicked: f => page.tweak("styleFont", f)
        }
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Form" }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Cards and rows:"
            textRole: "text"
            valueRole: "value"
            model: [{ text: "Filled boxes", value: "filled" }, { text: "Outlines", value: "outline" },
                    { text: "No boxes, thin dividers", value: "plain" }]
            currentIndex: Math.max(0, indexOfValue(page.cfg_styleCard))
            onActivated: page.tweak("styleCard", currentValue)
        }
        Tweak { Kirigami.FormData.label: "Spacing:"; from: 0; to: 100; suffix: ""; value: page.cfg_styleSpace; onMoved: v => page.tweak("styleSpace", v) }
        Tweak { Kirigami.FormData.label: "Number weight:"; from: 0; to: 100; suffix: ""; value: page.cfg_styleWeight; onMoved: v => page.tweak("styleWeight", v) }
        FontCombo {
            Kirigami.FormData.label: "Number font:"
            model: ["", "monospace"].concat(Qt.fontFamilies())
            value: page.cfg_styleNumFont
            emptyText: "Same as the text"
            onPicked: f => page.tweak("styleNumFont", f)
        }
        QQC2.CheckBox {
            text: "Labels in capitals"
            checked: page.cfg_styleCaps
            onToggled: page.tweak("styleCaps", checked)
        }
        Tweak { Kirigami.FormData.label: "Motion:"; from: 0; to: 100; suffix: ""; value: page.cfg_styleMotion; onMoved: v => page.tweak("styleMotion", v) }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Tip: right-click a widget and choose Next Style to flip through the presets without opening settings. "
                + "Theme colors follow your Plasma color scheme, including accent colors taken from the wallpaper."
        }
    }
}
