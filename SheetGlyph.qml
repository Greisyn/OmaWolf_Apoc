import QtQuick
import qs.Commons

// Theme-following line icons for the sheet, drawn like oShelf's Glyph:
// 1.5px round-cap strokes on a 22x22 grid, inked only with theme colors.
// Never hardcode a color here — pass Color.foreground / Color.accent.
Canvas {
  id: root
  property string kind: "pin"
  property color ink: Color.foreground
  width: 22; height: 22
  onKindChanged: requestPaint()
  onInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var c = getContext("2d");
    c.reset(); c.strokeStyle = ink; c.fillStyle = ink;
    c.lineWidth = 1.5; c.lineJoin = "round"; c.lineCap = "round";
    c.scale(width / 22, height / 22);
    c.beginPath();
    if (kind === "pin") {
      c.moveTo(7, 3); c.lineTo(15, 3); c.lineTo(14, 10);
      c.lineTo(17, 14); c.lineTo(5, 14); c.lineTo(8, 10); c.closePath();
      c.moveTo(11, 14); c.lineTo(11, 20);
    } else if (kind === "close") {
      c.moveTo(6, 6); c.lineTo(16, 16); c.moveTo(16, 6); c.lineTo(6, 16);
    } else if (kind === "check") {
      c.moveTo(5, 12.5); c.lineTo(9.5, 17); c.lineTo(17, 7);
    }
    c.stroke();
  }
}
