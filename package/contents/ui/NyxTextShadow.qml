import QtQuick
import QtQuick.Effects

// Soft shadow under text and icons, for busy wallpapers. Use as a layer.effect.
MultiEffect {
    required property var style
    shadowEnabled: true
    shadowColor: style.textShadowColor
    // stronger shadows also spread wider, so small text gets a dark halo on bright wallpapers
    shadowOpacity: Math.min(1, style.textShadow * 1.25)
    shadowBlur: 0.35 + style.textShadow * 0.4
    blurMax: 20
    shadowHorizontalOffset: 0
    shadowVerticalOffset: 1
}
