import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// "On click, open:" setting for a widget's config page; bind `text` to the page's cfg_clickAction
ColumnLayout {
    id: field
    property alias text: edit.text
    property string hint: ""
    spacing: Kirigami.Units.smallSpacing
    QQC2.TextField {
        id: edit
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        placeholderText: "Nothing"
    }
    QQC2.Label {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
        text: "An app (org.kde.dolphin), a web address or a command. Separate choices with ; and the first one "
            + "that's installed opens. Leave it empty to do nothing." + (field.hint ? " " + field.hint : "")
    }
}
