import QtQuick

// An inner card, row or tile drawn in the look's card style:
//   filled   a soft box tinted with the text color
//   outline  an empty box with a thin edge (accent edge when the look uses one)
//   plain    no box; a thin divider under it when `divider` is set
// Hover lifts it slightly, as much as the look's motion allows.
Item {
    id: card

    required property var style
    property real radius: style.innerRadius
    property bool hovered: false
    property bool highlighted: false
    property bool divider: true

    readonly property string kind: style.cardStyle
    scale: hovered ? 1 + style.motion * 0.035 : 1
    Behavior on scale { NumberAnimation { duration: card.style.motionMs; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        visible: card.kind !== "plain"
        radius: card.radius
        color: card.kind === "filled"
               ? (card.highlighted ? card.style.active : card.hovered ? card.style.cardHover : card.style.card)
               : (card.highlighted ? Qt.alpha(card.style.accent, 0.16) : card.hovered ? Qt.alpha(card.style.text, 0.05) : "transparent")
        border.width: card.kind === "outline" ? 1.5 : 1
        border.color: card.kind === "outline"
                      ? (card.highlighted || card.style.borderAccent ? Qt.alpha(card.style.accent, card.hovered ? 1 : 0.75)
                                                                    : Qt.alpha(card.style.text, card.hovered ? 0.5 : 0.3))
                      : (card.highlighted ? card.style.activeEdge : card.style.cardEdge)
        Behavior on color { ColorAnimation { duration: card.style.motionMs } }
    }
    Rectangle {
        visible: card.kind === "plain" && card.divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: card.highlighted ? Qt.alpha(card.style.accent, 0.8) : Qt.alpha(card.style.text, card.hovered ? 0.35 : 0.18)
    }
}
