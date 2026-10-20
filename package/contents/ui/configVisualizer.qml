import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQC

// "Visualizer" settings page: the look and the cava tuning of the audio visualizer card
KCM.SimpleKCM {
    id: page

    property alias cfg_visualizerBars: bars.value
    property alias cfg_vizShape: shape.currentIndex
    property alias cfg_vizGap: gap.value
    property alias cfg_vizRound: round.value
    property alias cfg_vizColorMode: colorMode.currentIndex
    property string cfg_vizColor
    property string cfg_vizColor2
    property alias cfg_vizPeaks: peaks.checked
    property alias cfg_vizShowInfo: showInfo.checked
    property int cfg_vizFps
    property alias cfg_vizSmooth: smooth.value
    property alias cfg_vizSens: sens.value
    property alias cfg_vizAutoSens: autoSens.checked

    readonly property var fpsChoices: [15, 25, 30, 60]

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Look" }

        QQC2.SpinBox { id: bars; Kirigami.FormData.label: "Bars:"; from: 4; to: 64 }
        QQC2.ComboBox {
            id: shape
            Kirigami.FormData.label: "Shape:"
            model: ["Mirrored (from the middle)", "From the bottom", "From the top"]
        }
        RowLayout {
            Kirigami.FormData.label: "Gap between bars:"
            QQC2.Slider { id: gap; from: 0; to: 100; stepSize: 5 }
            QQC2.Label { text: gap.value + " %" }
        }
        RowLayout {
            Kirigami.FormData.label: "Rounded corners:"
            QQC2.Slider { id: round; from: 0; to: 100; stepSize: 5 }
            QQC2.Label { text: round.value + " %" }
        }
        QQC2.CheckBox { id: peaks; Kirigami.FormData.label: "Peaks:"; text: "Show falling peak markers" }
        QQC2.CheckBox { id: showInfo; Kirigami.FormData.label: "Card:"; text: "Show the cover and title above the bars" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Colors" }

        QQC2.ComboBox {
            id: colorMode
            Kirigami.FormData.label: "Bar color:"
            model: ["Accent color", "Custom color", "Gradient"]
        }
        RowLayout {
            Kirigami.FormData.label: colorMode.currentIndex === 2 ? "Base / tip:" : "Color:"
            visible: colorMode.currentIndex > 0
            KQC.ColorButton {
                id: c1
                color: page.cfg_vizColor
                showAlphaChannel: false
                onAccepted: function (c) {
                    page.cfg_vizColor = c.toString()
                    c1.color = Qt.binding(function () { return page.cfg_vizColor })
                }
            }
            KQC.ColorButton {
                id: c2
                visible: colorMode.currentIndex === 2
                color: page.cfg_vizColor2
                showAlphaChannel: false
                onAccepted: function (c) {
                    page.cfg_vizColor2 = c.toString()
                    c2.color = Qt.binding(function () { return page.cfg_vizColor2 })
                }
            }
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Motion" }

        QQC2.ComboBox {
            Kirigami.FormData.label: "Speed:"
            model: ["15 fps (lightest)", "25 fps", "30 fps", "60 fps (smoothest, more CPU)"]
            currentIndex: Math.max(0, page.fpsChoices.indexOf(page.cfg_vizFps))
            onActivated: page.cfg_vizFps = page.fpsChoices[currentIndex]
        }
        RowLayout {
            Kirigami.FormData.label: "Smoothing:"
            QQC2.Slider { id: smooth; from: 0; to: 100; stepSize: 1 }
            QQC2.Label { text: smooth.value + " %" }
        }
        QQC2.CheckBox { id: autoSens; Kirigami.FormData.label: "Sensitivity:"; text: "Adjust automatically to the volume" }
        RowLayout {
            Kirigami.FormData.label: autoSens.checked ? "Starting sensitivity:" : "Sensitivity:"
            QQC2.Slider { id: sens; from: 10; to: 300; stepSize: 10 }
            QQC2.Label { text: sens.value + " %" }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "The visualizer card needs cava. Low smoothing makes the bars jumpy, high smoothing makes them slow."
        }
    }
}
