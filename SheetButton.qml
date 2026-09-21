import QtQuick
import QtQuick.Controls
import qs.Commons

// Filled push-button: clearly a button, not text. Accent-tinted fill,
// visible border, hover/press states. Ink always comes from the theme.
Rectangle {
  id: root
  property string label: ""
  property string hint: label
  signal pressed()
  implicitWidth: Math.max(76, caption.implicitWidth + 30)
  implicitHeight: 38
  radius: 11
  color: pointer.pressed ? Util.alpha(Color.accent, 0.28)
    : pointer.containsMouse || activeFocus ? Util.alpha(Color.accent, 0.20)
    : Util.alpha(Color.accent, 0.11)
  border.width: 1
  border.color: activeFocus ? Color.accent
    : pointer.containsMouse ? Util.alpha(Color.accent, 0.65)
    : Util.alpha(Color.accent, 0.4)
  scale: pointer.pressed ? 0.96 : 1
  Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
  Behavior on color { ColorAnimation { duration: 120 } }
  activeFocusOnTab: true
  opacity: enabled ? 1 : 0.4
  Accessible.role: Accessible.Button
  Accessible.name: hint
  Accessible.onPressAction: pressed()
  Keys.onReturnPressed: pressed()
  Keys.onSpacePressed: pressed()
  ToolTip.visible: pointer.containsMouse && hint !== "" && hint !== label
  ToolTip.text: hint
  ToolTip.delay: 650
  Text {
    id: caption
    anchors.centerIn: parent
    text: root.label
    textFormat: Text.PlainText
    color: Color.foreground
    font.family: Style.fontFamily
    font.pixelSize: 12
    font.weight: Font.DemiBold
  }
  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.pressed()
  }
}
