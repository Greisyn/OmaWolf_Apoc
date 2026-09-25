import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Settings panel. Opened from bar icon right-click only. This is the
// auto-closing one: an outside click dismisses it (native KeyboardPanel
// behavior), and it also closes by itself a few moments after the mouse
// stops hovering it — see pokeIdle()/idleTimer below. Close button and
// bar-icon toggle close it explicitly.
// All colors from Color.* / Style.* so omarchy themes repaint it live.
Panel {
  id: root
  moduleName: "local.werewolf-sheet"
  ipcTarget: "local.werewolf-sheet-panel"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  SheetConfig { id: config }

  // Explicit two-way sync with KeyboardPanel (id kbPanel below). The
  // declarative `open: root.opened` binding is one-way AND is permanently
  // severed the first time anything writes kbPanel.open directly (which is
  // what click-away dismiss does), so every path sets both ends explicitly
  // and never relies on the binding:
  //  - open()/close() here drive controller + panel together.
  //  - onOpenChanged pushes panel-side closes (dismiss) back to controller.
  function open() { root.controller.show(); kbPanel.open = true; root.pokeIdle(); }
  function close() { idleTimer.stop(); root.controller.hide(); kbPanel.open = false; }
  function toggle() { root.opened ? root.close() : root.open(); }

  // Idle auto-close: while the settings card is open, hovering it holds it
  // open; when the mouse isn't on it, idleTimer closes it a few moments
  // later (the countdown also runs from open, so an ignored settings card
  // never lingers). Re-entering cancels the countdown.
  function pokeIdle() {
    if (!kbPanel.open) { idleTimer.stop(); return; }
    if (settingsHover.hovered) idleTimer.stop();
    else idleTimer.restart();
  }
  Timer { id: idleTimer; interval: 3000; repeat: false; onTriggered: { if (kbPanel.open && !settingsHover.hovered) root.close(); } }

  component RowLabel: Text {
    textFormat: Text.PlainText
    color: root.contentForeground
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.body
  }

  component SectionHeader: Text {
    textFormat: Text.PlainText
    color: Color.accent
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.body
    font.bold: true
  }

  component SwitchRow: Row {
    property string label: ""
    property bool checked: false
    signal flipped()
    width: parent ? parent.width : 0
    spacing: Style.spacing.lg
    RowLabel { text: parent.label; width: parent.width - sw.width - parent.spacing; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight }
    ToggleSwitch {
      id: sw
      checked: parent.checked
      foreground: root.contentForeground
      accent: Color.accent
      anchors.verticalCenter: parent.verticalCenter
      onToggled: parent.flipped()
    }
  }

  KeyboardPanel {
    id: kbPanel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    // Two-way sync: click-away dismiss writes open=false directly on this
    // panel, bypassing PanelController (the open: binding is one-way).
    // Without this push-back, the next toggle() sees opened==true and
    // closes (invisibly) instead of opening.
    onOpenChanged: {
      if (open) root.pokeIdle();
      else { idleTimer.stop(); root.controller.hide(); }
    }
    centerOnBar: false
    contentWidth: fittedContentWidth(Style.space(440))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight)

    Flickable {
      anchors.fill: parent
      contentWidth: width
      contentHeight: contentColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      // Hover sensor for the idle auto-close. HoverHandler only observes —
      // it never grabs clicks, so scrolling, fields and buttons are
      // unaffected.
      HoverHandler {
        id: settingsHover
        onHoveredChanged: root.pokeIdle()
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.spacing.xl

        Image {
          width: parent.width; height: 56
          source: Qt.resolvedUrl("logo.png")
          fillMode: Image.PreserveAspectFit
          smooth: true
          opacity: 0.95
        }

        SectionHeader { text: "Sheet" }
        Row {
          width: parent.width; spacing: Style.spacing.sm
          WidgetButton { text: "Show"; onPressed: function() { Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "show"]); } }
          WidgetButton { text: "Hide"; onPressed: function() { Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "hide"]); } }
          WidgetButton { text: "Toggle"; onPressed: function() { Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "toggle"]); } }
          WidgetButton { text: "Export"; onPressed: function() { Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "exportSheet"]); } }
        }
        SwitchRow { label: "Pin (X cannot close until unpinned)"; checked: config.keepOpen; onFlipped: config.set("keepOpen", !config.keepOpen) }

        SectionHeader { text: "Card placement" }
        RowLabel {
          width: parent.width; wrapMode: Text.WordWrap
          text: "The sheet opens from the bar icon. Drag its header to float it anywhere — the drop position is saved. Corner buttons snap it back."
        }
        RowLabel {
          width: parent.width; wrapMode: Text.WordWrap
          text: config.placeMode === "free" ? "Card is free-floating (dragged to its spot)." : "Card is snapped to a corner."
        }
        Row {
          width: parent.width; spacing: Style.spacing.sm
          WidgetButton { text: "TL"; active: config.placeMode === "corner" && config.corner === "topLeft"; onPressed: function() { config.set("corner", "topLeft"); config.set("placeMode", "corner"); } }
          WidgetButton { text: "TR"; active: config.placeMode === "corner" && config.corner === "topRight"; onPressed: function() { config.set("corner", "topRight"); config.set("placeMode", "corner"); } }
          WidgetButton { text: "BL"; active: config.placeMode === "corner" && config.corner === "bottomLeft"; onPressed: function() { config.set("corner", "bottomLeft"); config.set("placeMode", "corner"); } }
          WidgetButton { text: "BR"; active: config.placeMode === "corner" && config.corner === "bottomRight"; onPressed: function() { config.set("corner", "bottomRight"); config.set("placeMode", "corner"); } }
        }
        Row {
          width: parent.width; spacing: Style.spacing.lg
          Column { width: (parent.width - parent.spacing) / 2; spacing: 2
            RowLabel { text: "Margin X (" + config.cornerMarginX + ")"; width: parent.width }
            PanelSlider {
              width: parent.width
              minimum: 0; maximum: 200; step: 2
              value: config.cornerMarginX
              onMoved: function(v) { config.set("cornerMarginX", Math.round(v)); }
            }
          }
          Column { width: (parent.width - parent.spacing) / 2; spacing: 2
            RowLabel { text: "Margin Y (" + config.cornerMarginY + ")"; width: parent.width }
            PanelSlider {
              width: parent.width
              minimum: 0; maximum: 200; step: 2
              value: config.cornerMarginY
              onMoved: function(v) { config.set("cornerMarginY", Math.round(v)); }
            }
          }
        }
        Row {
          width: parent.width; spacing: Style.spacing.lg
          Column { width: (parent.width - parent.spacing) / 2; spacing: 2
            RowLabel { text: "Width (" + config.sideWidth + ", min 600)"; width: parent.width }
            PanelSlider {
              width: parent.width
              minimum: 600; maximum: 700; step: 10
              value: config.sideWidth
              onMoved: function(v) { config.set("sideWidth", Math.round(v)); }
            }
          }
          Column { width: (parent.width - parent.spacing) / 2; spacing: 2
            RowLabel { text: "Height (" + config.sideHeight + ", min 550)"; width: parent.width }
            PanelSlider {
              width: parent.width
              minimum: 550; maximum: 1000; step: 10
              value: config.sideHeight
              onMoved: function(v) { config.set("sideHeight", Math.round(v)); }
            }
          }
        }

        SectionHeader { text: "Output folder (.txt for LLM)" }
        RowLabel { width: parent.width; wrapMode: Text.WordWrap; text: "Exports are named per character (<Name>.txt), so each character gets its own file." }
        TextField {
          width: parent.width
          text: config.outputDir
          placeholderText: "/home/you/Pictures"
          foreground: root.contentForeground
          font.family: root.contentFontFamily
          onEditingFinished: { if (text !== "") config.set("outputDir", text); }
          onAccepted: { if (text !== "") config.set("outputDir", text); }
        }
        Row {
          width: parent.width; spacing: Style.spacing.sm
          WidgetButton { text: "Export now"; onPressed: function() { Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "exportSheet"]); } }
          WidgetButton { text: "Reset settings"; onPressed: function() { config.resetAll(); } }
          WidgetButton { text: "Close"; onPressed: function() { root.close(); } }
        }

        SectionHeader { text: "Motion" }
        SwitchRow { label: "Reduced motion"; checked: config.reducedMotion; onFlipped: config.set("reducedMotion", !config.reducedMotion) }
        RowLabel { text: "Card open/close motion (" + config.motionDuration + "ms, 0 = instant)"; width: parent.width }
        PanelSlider {
          width: parent.width
          minimum: 0; maximum: 600; step: 10
          value: config.motionDuration
          onMoved: function(v) { config.set("motionDuration", Math.round(v)); }
        }
      }
    }
  }
}
