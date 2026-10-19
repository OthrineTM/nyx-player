import QtQuick
import QtQuick.Effects

// Soft shadow under text and icons, for busy wallpapers. Use as a layer.effect.
MultiEffect {
    required property var style
    shadowEnabled: true
    shadowColor: style.textShadowColor
    shadowOpacity: Math.min(1, style.textShadow * 1.2)
    shadowBlur: 0.5
    blurMax: 16
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 1
}
