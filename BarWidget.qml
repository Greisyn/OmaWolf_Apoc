import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Bar surface: icon ONLY. The sheet card is bar-icon-driven (no floating
// anchor): left-click toggles, right-click opens settings.
BarWidget {
  id: root
  moduleName: "local.werewolf-sheet"

  function injectPanel() {
    var target = panelLoader.item;
    if (!target) return;
    if ("bar" in target) target.bar = root.bar;
    if ("settings" in target) target.settings = root.settings;
    if ("anchorItem" in target) target.anchorItem = button;
    if ("hostWidget" in target) target.hostWidget = root;
  }

  readonly property var sheetService: bar && bar.shell ? bar.shell.serviceFor("local.werewolf-sheet") : null
  readonly property string charName: sheetService ? String(sheetService.charName || "") : ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: root.injectPanel()
  onSettingsChanged: root.injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: vertical ? -1 : Style.bar.iconSlot
    text: ""
    labelVisible: false
    hasVisualContent: true
    active: false
    useActiveColor: false
    tooltipText: (root.charName !== "" ? root.charName : "Werewolf Sheet") + "\nLeft click: toggle sheet\nRight click: settings"

    Image {
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      source: Qt.resolvedUrl("anchor-icon.png")
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }

    onPressed: function(b) {
      if (!root.bar) return;
      if (b === Qt.RightButton) {
        if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle();
        return;
      }
      if (b === Qt.LeftButton) {
        Quickshell.execDetached(["omarchy-shell", "local.werewolf-sheet", "toggle"]);
      }
    }
  }
}
