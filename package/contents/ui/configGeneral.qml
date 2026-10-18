import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_compactStyle: compactStyle.currentIndex
    property alias cfg_compactWidth: compactWidth.value
    property alias cfg_coverStyle: coverStyle.currentIndex
    property alias cfg_deskFace: deskFace.currentIndex
    property alias cfg_visualizerBars: visualizerBars.value
    property alias cfg_accentFromArt: accentFromArt.checked
    property alias cfg_preferLocal: preferLocal.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "In the panel" }

        QQC2.ComboBox {
            id: compactStyle
            Kirigami.FormData.label: "Show:"
            model: ["Cover, title and controls", "Cover and title", "Cover and controls"]
        }
        RowLayout {
            Kirigami.FormData.label: "Width:"
            enabled: compactStyle.currentIndex !== 2
            QQC2.SpinBox { id: compactWidth; from: 120; to: 600; stepSize: 10 }
            QQC2.Label { text: "px" }
        }
        QQC2.ComboBox {
            id: coverStyle
            Kirigami.FormData.label: "Popup cover:"
            model: ["Spinning vinyl", "Square", "Round"]
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "On the desktop" }

        QQC2.ComboBox {
            id: deskFace
            Kirigami.FormData.label: "Card:"
            model: ["Album (cover fills the card)", "Wide (cover beside the controls)", "Vinyl", "Easy Effects", "Audio visualizer"]
        }
        RowLayout {
            Kirigami.FormData.label: "Visualizer bars:"
            enabled: deskFace.currentIndex === 4
            QQC2.SpinBox { id: visualizerBars; from: 4; to: 64 }
            QQC2.Label { text: "needs cava"; opacity: 0.7 }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: "Drag the player onto the desktop to use a card. Right-click it and choose Next Card to flip through them."
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Behavior" }

        QQC2.CheckBox {
            id: accentFromArt
            Kirigami.FormData.label: "Colors:"
            text: "Take the accent color from the album art"
        }
        QQC2.CheckBox {
            id: preferLocal
            Kirigami.FormData.label: "Players:"
            text: "Prefer this computer's players over phones"
        }
    }
}
