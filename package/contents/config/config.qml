import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "General"
        icon: "configure"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: "Style"
        icon: "preferences-desktop-theme"
        source: "configStyle.qml"
    }
}
