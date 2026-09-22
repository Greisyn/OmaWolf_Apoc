pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Corner-anchored floating sheet editor, modeled on local.disk-mounter
// DriveWindow: a small always-visible square in a screen corner showing the
// W icon — hover-dwell (or tap) reveals the sheet card, leaving collapses it.
// Only the square and the open card take input; all other pixels pass
// through to the desktop via the layer-shell input mask.
// All colors via Color.* / Style.* so omarchy themes repaint it live.
PanelWindow {
  id: root
  required property var service
  required property var cfg

  readonly property bool showAnchor: cfg.showAnchor
  readonly property bool freeMode: cfg.anchorMode === "free"
  readonly property bool atRight: cfg.corner === "topRight" || cfg.corner === "bottomRight"
  readonly property bool atBottom: cfg.corner === "bottomLeft" || cfg.corner === "bottomRight"
  readonly property real topClearance: 44 // keep clear of the top bar
  readonly property bool reducedMotion: cfg.reducedMotion
  property bool expanded: false
  property real openness: expanded ? 1 : 0
  property real dwellProgress: 0
  // live drag offset (pixels from press origin while dragging)
  property real dragDX: 0
  property real dragDY: 0
  readonly property bool dragging: dragHandler.active
  readonly property bool engaged: cornerHover.hovered || panelHover.hovered || cfg.keepOpen || root.dragging
  readonly property real btnSize: cfg.buttonSize
  // corner-snap base position
  readonly property real cornerBaseX: atRight ? width - btnSize - cfg.cornerMarginX : cfg.cornerMarginX
  readonly property real cornerBaseY: atBottom ? height - btnSize - cfg.cornerMarginY : cfg.cornerMarginY + topClearance
  // free-floating base position (square center fractions)
  readonly property real freeBaseX: cfg.freeX * width - btnSize / 2
  readonly property real freeBaseY: cfg.freeY * height - btnSize / 2
  readonly property real baseX: freeMode ? freeBaseX : cornerBaseX
  readonly property real baseY: freeMode ? freeBaseY : cornerBaseY
  readonly property real btnX: {
    if (!showAnchor) return -1000; // park offscreen so the input mask stays clear
    return Math.max(4, Math.min(width - btnSize - 4, baseX + (dragging ? dragDX : 0)));
  }
  readonly property real btnY: {
    if (!showAnchor) return -1000;
    return Math.max(4, Math.min(height - btnSize - 4, baseY + (dragging ? dragDY : 0)));
  }
  readonly property real cardW: Math.min(width - 32, cfg.sideWidth)
  readonly property real cardH: Math.min(height - 32, cfg.sideHeight)
  // corner-snap card position (below/above the square, clear of the bar)
  readonly property real cornerCardX: {
    var x = atRight ? width - cardW - cfg.cornerMarginX : cfg.cornerMarginX;
    return Math.max(16, Math.min(width - cardW - 16, x));
  }
  readonly property real cornerCardY: {
    var y = atBottom ? height - cardH - cfg.cornerMarginY - (showAnchor ? btnSize + 12 : 16)
      : cfg.cornerMarginY + topClearance + (showAnchor ? btnSize + 12 : 16);
    return Math.max(16, Math.min(height - cardH - 16, y));
  }
  // free-floating card position (beside the square, clamped on-screen)
  readonly property real cardX: {
    if (!freeMode) return cornerCardX;
    return Math.max(16, Math.min(width - cardW - 16, btnX + btnSize / 2 - cardW / 2));
  }
  readonly property real cardY: {
    if (!freeMode) return cornerCardY;
    var below = btnY + btnSize + 12;
    var above = btnY - cardH - 12;
    var y = (btnY + btnSize / 2 > height / 2) ? above : below;
    return Math.max(16, Math.min(height - cardH - 16, y));
  }

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "werewolf-sheet"
  WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region {
    item: cornerBtn
    Region {
      x: surface.x; y: surface.y
      width: root.expanded ? surface.width : 0; height: surface.height
      radius: surface.radius
    }
  }

  Behavior on openness {
    NumberAnimation {
      duration: root.reducedMotion ? 0 : root.expanded ? cfg.motionDuration : Math.round(cfg.motionDuration * 0.75)
      easing.type: Easing.OutCubic
    }
  }

  function reveal() {
    closeTimer.stop(); stopDwell();
    if (expanded) return;
    expanded = true;
    content.forceActiveFocus();
  }
  function collapse() {
    if (cfg.keepOpen) return;
    expanded = false;
    stopDwell();
  }
  function toggle() { expanded ? collapse() : reveal(); }
  // Commit every visible text field into the sheet (text the user typed but
  // never tabbed out of). Called before export/copy so nothing is lost.
  function flushAll() {
    function walk(item) {
      if (!item || !item.children) return;
      if (typeof item.flush === "function") {
        try { item.flush(); } catch (e) {}
      }
      var kids = item.children;
      for (var i = 0; i < kids.length; i++) walk(kids[i]);
    }
    walk(body);
  }
  function stopDwell() { hoverTimer.stop(); dwell.stop(); dwellProgress = 0; }
  function startDwell() {
    if (expanded || !cornerHover.hovered || root.dragging) return;
    stopDwell();
    hoverTimer.restart(); dwell.restart();
  }
  // Drop the square: snap to a nearby corner, else float where released.
  function commitDrag() {
    var cx = root.baseX + root.dragDX + root.btnSize / 2;
    var cy = root.baseY + root.dragDY + root.btnSize / 2;
    root.dragDX = 0; root.dragDY = 0;
    var names = ["topLeft", "topRight", "bottomLeft", "bottomRight"];
    var px = [0, width, 0, width];
    var py = [0, 0, height, height];
    var best = -1; var bestD = 150;
    for (var i = 0; i < 4; i++) {
      var dx = cx - px[i], dy = cy - py[i];
      var d = Math.sqrt(dx * dx + dy * dy);
      if (d < bestD) { bestD = d; best = i; }
    }
    if (best >= 0) {
      cfg.set("corner", names[best]);
      cfg.set("anchorMode", "corner");
    } else {
      cfg.set("anchorMode", "free");
      cfg.set("freeX", Math.max(0.02, Math.min(0.98, cx / width)));
      cfg.set("freeY", Math.max(0.02, Math.min(0.98, cy / height)));
    }
  }

  onEngagedChanged: { if (engaged) closeTimer.stop(); else if (expanded) closeTimer.restart(); }
  // Refresh the import path each time the card opens so it tracks the
  // current output folder instead of going stale after settings edits.
  onExpandedChanged: { if (expanded) importField.text = cfg.outputDir + "/"; }

  Timer { id: closeTimer; interval: cfg.closeDelay; onTriggered: { if (!root.engaged) root.collapse(); } }
  Timer { id: hoverTimer; interval: cfg.openDelay; onTriggered: { if (cornerHover.hovered && !root.dragging) root.reveal(); } }
  NumberAnimation { id: dwell; target: root; property: "dwellProgress"; from: 0; to: 1; duration: cfg.openDelay }

  // ---- corner square with W icon ----
  Rectangle {
    id: cornerBtn
    objectName: "werewolf-sheet-corner"
    x: root.btnX; y: root.btnY
    width: root.btnSize; height: root.btnSize
    radius: 16
    color: Color.background
    border.width: 1
    border.color: cornerHover.hovered ? Color.accent : Util.alpha(Color.foreground, 0.15)
    opacity: 1 - root.openness * 0.85
    visible: root.showAnchor && opacity > 0
    layer.enabled: visible
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.5; shadowVerticalOffset: 4 }
    HoverHandler {
      id: cornerHover
      onHoveredChanged: { if (hovered) root.startDwell(); else root.stopDwell(); }
    }
    // Click-hold to drag the square anywhere; drop near a corner to snap.
    // A plain tap (no drag) still toggles via TapHandler below.
    DragHandler {
      id: dragHandler
      target: null
      enabled: root.showAnchor && !cfg.anchorLocked
      onActiveChanged: {
        if (active) { root.dragDX = 0; root.dragDY = 0; root.stopDwell(); }
        else root.commitDrag();
      }
      onTranslationChanged: { root.dragDX = translation.x; root.dragDY = translation.y; }
    }
    Image {
      anchors.centerIn: parent
      width: parent.width - 20; height: parent.height - 20
      source: Qt.resolvedUrl("anchor-icon.png")
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
    }
    // dwell fill bar (bottom edge of the square)
    Rectangle {
      anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 8 }
      height: 2; radius: 1
      color: "transparent"
      Rectangle {
        width: parent.width * root.dwellProgress; height: parent.height
        radius: 1; color: Color.accent
        visible: root.dwellProgress > 0 && !root.expanded
      }
    }
    TapHandler { onTapped: root.toggle() }
  }

  // ---- sheet card ----
  Rectangle {
    id: surface
    objectName: "werewolf-sheet-surface"
    x: root.cardX
    y: root.cardY + (root.reducedMotion ? 0 : (1 - root.openness) * (root.atBottom ? 32 : -32))
    width: root.cardW; height: root.cardH
    scale: root.reducedMotion ? 1 : 0.97 + root.openness * 0.03
    opacity: root.openness
    visible: root.openness > 0
    radius: 24
    color: Color.background
    border.width: 1
    border.color: Util.alpha(Color.foreground, 0.15)
    layer.enabled: visible
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.35; shadowBlur: 0.65; shadowVerticalOffset: 8 }
    HoverHandler { id: panelHover }

    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
      height: Math.min(parent.height, 120); radius: 23
      gradient: Gradient {
        GradientStop { position: 0; color: Util.alpha(Color.accent, 0.08) }
        GradientStop { position: 1; color: "transparent" }
      }
    }

    FocusScope {
      id: content
      anchors.fill: parent
      Keys.onEscapePressed: { if (confirm.opened) confirm.canceled(); else root.collapse(); }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_PageUp) {
          scroller.contentY = Math.max(0, scroller.contentY - scroller.height);
          event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
          scroller.contentY = Math.min(Math.max(0, scroller.contentHeight - scroller.height), scroller.contentY + scroller.height);
          event.accepted = true;
        }
      }

      // header: transparent W20 logo only
      Image {
        id: logo
        x: 18; y: 12; width: 210; height: 76
        source: Qt.resolvedUrl("logo.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: 0.95
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 14; y: 22; spacing: 2
        SheetAction { icon: "pin"; hint: cfg.keepOpen ? "Unpin (auto-collapse)" : "Pin open"; selected: cfg.keepOpen; onTriggered: cfg.set("keepOpen", !cfg.keepOpen) }
        SheetAction { icon: "close"; hint: "Close sheet"; onTriggered: root.collapse() }
      }

      Flickable {
        id: scroller
        x: 16; y: 96; width: parent.width - 32; height: parent.height - 96 - 64
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        QQC.ScrollBar.vertical: QQC.ScrollBar {
          id: vbar
          policy: QQC.ScrollBar.AlwaysOn
          contentItem: Rectangle {
            implicitWidth: 6; radius: 3
            color: Util.alpha(Color.foreground, (vbar.pressed || vbar.active) ? 0.45 : 0.22)
          }
          background: Rectangle {
            implicitWidth: 6; radius: 3
            color: Util.alpha(Color.foreground, 0.07)
          }
        }

        Column {
          id: body
          width: scroller.width
          spacing: 8

          SectionHeader { text: "IDENTITY" }
          FieldRow { label: "Name"; initial: service.charName; onCommit: function(v) { service.charName = v; service.saveSoon(); } }
          FieldRow { label: "Player"; initial: service.player; onCommit: function(v) { service.player = v; service.saveSoon(); } }
          FieldRow { label: "Chronicle"; initial: service.chronicle; onCommit: function(v) { service.chronicle = v; service.saveSoon(); } }
          FieldRow { label: "Breed"; initial: service.breed; onCommit: function(v) { service.breed = v; service.saveSoon(); } }
          FieldRow { label: "Auspice"; initial: service.auspice; onCommit: function(v) { service.auspice = v; service.saveSoon(); } }
          FieldRow { label: "Tribe"; initial: service.tribe; onCommit: function(v) { service.tribe = v; service.saveSoon(); } }
          FieldRow { label: "Rank"; initial: service.rank; onCommit: function(v) { service.rank = v; service.saveSoon(); } }
          FieldRow { label: "Concept"; initial: service.concept; onCommit: function(v) { service.concept = v; service.saveSoon(); } }
          FieldRow { label: "Nature"; initial: service.nature; onCommit: function(v) { service.nature = v; service.saveSoon(); } }
          FieldRow { label: "Demeanor"; initial: service.demeanor; onCommit: function(v) { service.demeanor = v; service.saveSoon(); } }
          FieldRow { label: "Pack"; initial: service.packName; onCommit: function(v) { service.packName = v; service.saveSoon(); } }
          FieldRow { label: "Totem"; initial: service.packTotem; onCommit: function(v) { service.packTotem = v; service.saveSoon(); } }
          FieldRow { label: "Sept"; initial: service.sept; onCommit: function(v) { service.sept = v; service.saveSoon(); } }

          SectionSeparator { }
          SectionHeader { text: "ATTRIBUTES" }
          DotRow { label: "Strength"; value: service.str; onDec: function() { service.bump("str", -1, 0, 5); } onInc: function() { service.bump("str", 1, 0, 5); } }
          DotRow { label: "Dexterity"; value: service.dex; onDec: function() { service.bump("dex", -1, 0, 5); } onInc: function() { service.bump("dex", 1, 0, 5); } }
          DotRow { label: "Stamina"; value: service.sta; onDec: function() { service.bump("sta", -1, 0, 5); } onInc: function() { service.bump("sta", 1, 0, 5); } }
          DotRow { label: "Charisma"; value: service.cha; onDec: function() { service.bump("cha", -1, 0, 5); } onInc: function() { service.bump("cha", 1, 0, 5); } }
          DotRow { label: "Manipulation"; value: service.man; onDec: function() { service.bump("man", -1, 0, 5); } onInc: function() { service.bump("man", 1, 0, 5); } }
          DotRow { label: "Appearance"; value: service.app; onDec: function() { service.bump("app", -1, 0, 5); } onInc: function() { service.bump("app", 1, 0, 5); } }
          DotRow { label: "Perception"; value: service.per; onDec: function() { service.bump("per", -1, 0, 5); } onInc: function() { service.bump("per", 1, 0, 5); } }
          DotRow { label: "Intelligence"; value: service.intl; onDec: function() { service.bump("intl", -1, 0, 5); } onInc: function() { service.bump("intl", 1, 0, 5); } }
          DotRow { label: "Wits"; value: service.wit; onDec: function() { service.bump("wit", -1, 0, 5); } onInc: function() { service.bump("wit", 1, 0, 5); } }

          SectionSeparator { }
          SectionHeader { text: "TALENTS" }
          DotRow { label: "Alertness"; value: service.alertness; onDec: function() { service.bump("alertness", -1, 0, 5); } onInc: function() { service.bump("alertness", 1, 0, 5); } }
          DotRow { label: "Athletics"; value: service.athletics; onDec: function() { service.bump("athletics", -1, 0, 5); } onInc: function() { service.bump("athletics", 1, 0, 5); } }
          DotRow { label: "Brawl"; value: service.brawl; onDec: function() { service.bump("brawl", -1, 0, 5); } onInc: function() { service.bump("brawl", 1, 0, 5); } }
          DotRow { label: "Empathy"; value: service.empathy; onDec: function() { service.bump("empathy", -1, 0, 5); } onInc: function() { service.bump("empathy", 1, 0, 5); } }
          DotRow { label: "Expression"; value: service.expression; onDec: function() { service.bump("expression", -1, 0, 5); } onInc: function() { service.bump("expression", 1, 0, 5); } }
          DotRow { label: "Intimidation"; value: service.intimidation; onDec: function() { service.bump("intimidation", -1, 0, 5); } onInc: function() { service.bump("intimidation", 1, 0, 5); } }
          DotRow { label: "Leadership"; value: service.leadership; onDec: function() { service.bump("leadership", -1, 0, 5); } onInc: function() { service.bump("leadership", 1, 0, 5); } }
          DotRow { label: "Primal-Urge"; value: service.primalUrge; onDec: function() { service.bump("primalUrge", -1, 0, 5); } onInc: function() { service.bump("primalUrge", 1, 0, 5); } }
          DotRow { label: "Streetwise"; value: service.streetwise; onDec: function() { service.bump("streetwise", -1, 0, 5); } onInc: function() { service.bump("streetwise", 1, 0, 5); } }
          DotRow { label: "Subterfuge"; value: service.subterfuge; onDec: function() { service.bump("subterfuge", -1, 0, 5); } onInc: function() { service.bump("subterfuge", 1, 0, 5); } }

          SectionSeparator { }
          SectionHeader { text: "SKILLS" }
          DotRow { label: "Animal Ken"; value: service.animalKen; onDec: function() { service.bump("animalKen", -1, 0, 5); } onInc: function() { service.bump("animalKen", 1, 0, 5); } }
          DotRow { label: "Crafts"; value: service.crafts; onDec: function() { service.bump("crafts", -1, 0, 5); } onInc: function() { service.bump("crafts", 1, 0, 5); } }
          DotRow { label: "Drive"; value: service.drive; onDec: function() { service.bump("drive", -1, 0, 5); } onInc: function() { service.bump("drive", 1, 0, 5); } }
          DotRow { label: "Etiquette"; value: service.etiquette; onDec: function() { service.bump("etiquette", -1, 0, 5); } onInc: function() { service.bump("etiquette", 1, 0, 5); } }
          DotRow { label: "Firearms"; value: service.firearms; onDec: function() { service.bump("firearms", -1, 0, 5); } onInc: function() { service.bump("firearms", 1, 0, 5); } }
          DotRow { label: "Larceny"; value: service.larceny; onDec: function() { service.bump("larceny", -1, 0, 5); } onInc: function() { service.bump("larceny", 1, 0, 5); } }
          DotRow { label: "Melee"; value: service.melee; onDec: function() { service.bump("melee", -1, 0, 5); } onInc: function() { service.bump("melee", 1, 0, 5); } }
          DotRow { label: "Performance"; value: service.performance; onDec: function() { service.bump("performance", -1, 0, 5); } onInc: function() { service.bump("performance", 1, 0, 5); } }
          DotRow { label: "Stealth"; value: service.stealth; onDec: function() { service.bump("stealth", -1, 0, 5); } onInc: function() { service.bump("stealth", 1, 0, 5); } }
          DotRow { label: "Survival"; value: service.survival; onDec: function() { service.bump("survival", -1, 0, 5); } onInc: function() { service.bump("survival", 1, 0, 5); } }

          SectionSeparator { }
          SectionHeader { text: "KNOWLEDGES" }
          DotRow { label: "Academics"; value: service.academics; onDec: function() { service.bump("academics", -1, 0, 5); } onInc: function() { service.bump("academics", 1, 0, 5); } }
          DotRow { label: "Computer"; value: service.computer; onDec: function() { service.bump("computer", -1, 0, 5); } onInc: function() { service.bump("computer", 1, 0, 5); } }
          DotRow { label: "Enigmas"; value: service.enigmas; onDec: function() { service.bump("enigmas", -1, 0, 5); } onInc: function() { service.bump("enigmas", 1, 0, 5); } }
          DotRow { label: "Investigation"; value: service.investigation; onDec: function() { service.bump("investigation", -1, 0, 5); } onInc: function() { service.bump("investigation", 1, 0, 5); } }
          DotRow { label: "Law"; value: service.law; onDec: function() { service.bump("law", -1, 0, 5); } onInc: function() { service.bump("law", 1, 0, 5); } }
          DotRow { label: "Medicine"; value: service.medicine; onDec: function() { service.bump("medicine", -1, 0, 5); } onInc: function() { service.bump("medicine", 1, 0, 5); } }
          DotRow { label: "Occult"; value: service.occult; onDec: function() { service.bump("occult", -1, 0, 5); } onInc: function() { service.bump("occult", 1, 0, 5); } }
          DotRow { label: "Rituals"; value: service.rituals; onDec: function() { service.bump("rituals", -1, 0, 5); } onInc: function() { service.bump("rituals", 1, 0, 5); } }
          DotRow { label: "Science"; value: service.science; onDec: function() { service.bump("science", -1, 0, 5); } onInc: function() { service.bump("science", 1, 0, 5); } }
          DotRow { label: "Technology"; value: service.technology; onDec: function() { service.bump("technology", -1, 0, 5); } onInc: function() { service.bump("technology", 1, 0, 5); } }

          SectionSeparator { }
          SectionHeader { text: "RENOWN / POOLS" }
          DotRow { label: "Rage"; max: 10; value: service.rage; onDec: function() { service.bump("rage", -1, 0, 10); } onInc: function() { service.bump("rage", 1, 0, 10); } }
          DotRow { label: "Gnosis"; max: 10; value: service.gnosis; onDec: function() { service.bump("gnosis", -1, 0, 10); } onInc: function() { service.bump("gnosis", 1, 0, 10); } }
          DotRow { label: "Willpower"; max: 10; value: service.willpower; onDec: function() { service.bump("willpower", -1, 0, 10); } onInc: function() { service.bump("willpower", 1, 0, 10); } }
          DotRow { label: "Glory"; max: 10; value: service.glory; onDec: function() { service.bump("glory", -1, 0, 10); } onInc: function() { service.bump("glory", 1, 0, 10); } }
          DotRow { label: "Honor"; max: 10; value: service.honor; onDec: function() { service.bump("honor", -1, 0, 10); } onInc: function() { service.bump("honor", 1, 0, 10); } }
          DotRow { label: "Wisdom"; max: 10; value: service.wisdom; onDec: function() { service.bump("wisdom", -1, 0, 10); } onInc: function() { service.bump("wisdom", 1, 0, 10); } }
          DotRow { label: "Experience"; max: 10; value: service.experience; onDec: function() { service.bump("experience", -1, 0, 10); } onInc: function() { service.bump("experience", 1, 0, 10); } }

          SectionSeparator { }
          SectionHeader { text: "ADVANTAGES / DESCRIPTION" }
          MultiLine { label: "Backgrounds"; initial: service.backgrounds; onCommit: function(v) { service.backgrounds = v; service.saveSoon(); } }
          MultiLine { label: "Gifts (one per line)"; initial: service.gifts; onCommit: function(v) { service.gifts = v; service.saveSoon(); } }
          MultiLine { label: "Rites"; initial: service.rites; onCommit: function(v) { service.rites = v; service.saveSoon(); } }
          MultiLine { label: "Fetishes"; initial: service.fetishes; onCommit: function(v) { service.fetishes = v; service.saveSoon(); } }
          MultiLine { label: "Merits"; initial: service.merits; onCommit: function(v) { service.merits = v; service.saveSoon(); } }
          MultiLine { label: "Flaws"; initial: service.flaws; onCommit: function(v) { service.flaws = v; service.saveSoon(); } }
          MultiLine { label: "Gear / Equipment"; initial: service.gear; onCommit: function(v) { service.gear = v; service.saveSoon(); } }
          MultiLine { label: "History"; initial: service.history; onCommit: function(v) { service.history = v; service.saveSoon(); } }
          MultiLine { label: "Appearance"; initial: service.appearance; onCommit: function(v) { service.appearance = v; service.saveSoon(); } }
          MultiLine { label: "Personality"; initial: service.personality; onCommit: function(v) { service.personality = v; service.saveSoon(); } }
          MultiLine { label: "Goals"; initial: service.goals; onCommit: function(v) { service.goals = v; service.saveSoon(); } }
          MultiLine { label: "OOC instructions to LLM"; initial: service.ooc; onCommit: function(v) { service.ooc = v; service.saveSoon(); } }

          SectionSeparator { }
          SectionHeader { text: "CHARACTER FILE (export / import)" }
          Text {
            width: parent.width
            text: "Folder: " + cfg.outputDir
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Util.alpha(Color.foreground, 0.6)
            font.family: Style.fontFamily; font.pixelSize: 10
          }
          Text {
            width: parent.width
            text: "File: " + service.exportFileName()
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Color.accent
            font.family: Style.fontFamily; font.pixelSize: 11; font.bold: true
          }
          Row {
            width: parent.width; spacing: 8
            SheetButton { label: "Export"; hint: "Save plain-text sheet, named per character"; onPressed: function() { root.flushAll(); service.exportNow(); } }
            SheetButton { label: "Copy"; hint: "Copy plain-text sheet for LLM chat"; onPressed: function() { root.flushAll(); service.copyForLLM(); } }
            SheetButton { label: "Clear…"; hint: "Reset the whole sheet (asks first)"; onPressed: function() { confirm.opened = true; } }
          }
          Text {
            width: parent.width
            text: service.status
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Color.accent
            font.family: Style.fontFamily; font.pixelSize: 10
          }
          Text {
            width: parent.width
            text: "Import plain-text sheet file:"
            textFormat: Text.PlainText
            color: Util.alpha(Color.foreground, 0.65)
            font.family: Style.fontFamily; font.pixelSize: 11
          }
          TextField {
            id: importField
            width: parent.width
            text: cfg.outputDir + "/"
            placeholderText: "Full path to an exported .txt sheet"
            onAccepted: { service.importSheet(text); }
          }
          Row {
            width: parent.width; spacing: 8
            SheetButton { label: "Import"; hint: "Load sheet from the path above"; onPressed: function() { service.importSheet(importField.text); } }
          }
        }
      }

      Rectangle {
        x: 16; y: parent.height - 56; width: parent.width - 32; height: 1
        color: Util.alpha(Color.foreground, 0.075)
      }
      Text {
        x: 18; y: parent.height - 40; width: parent.width - 36
        text: root.showAnchor ? (cfg.anchorLocked ? "Square locked · unlock in settings to drag · Esc closes" : "Drag the W square to move · drop near a corner to snap · Esc closes") : "Square hidden — open from the bar icon · Esc closes"
        textFormat: Text.PlainText; elide: Text.ElideRight
        color: Util.alpha(Color.foreground, 0.45)
        font.family: Style.fontFamily; font.pixelSize: 10
      }
    }

    ConfirmDialog {
      id: confirm
      anchors.fill: parent
      message: "Clear the entire sheet? All fields return to blank defaults. This cannot be undone."
      cancelText: "Keep"
      confirmText: "Clear"
      onCanceled: opened = false
      onConfirmed: { opened = false; service.clearSheet(); }
    }
  }

  // ---- reusable rows ----
  component SectionHeader: Text {
    textFormat: Text.PlainText
    color: Color.accent
    font.family: Style.fontFamily
    font.pixelSize: 10
    font.bold: true
    font.letterSpacing: 1.2
  }

  // Divider between sheet groups (identity / attributes / talents / ...),
  // mirroring the sections of the paper character sheet.
  component SectionSeparator: Item {
    width: parent ? parent.width : 0
    height: 12
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 1
      color: Util.alpha(Color.accent, 0.28)
    }
  }

  component FieldRow: Row {
    property string label: ""
    property string initial: ""
    signal commit(string value)
    // Push the visible text into the sheet (used by the Set button and
    // by flushAll before export — committing an unchanged value is a no-op).
    function flush() { commit(tf.text); }
    width: parent ? parent.width : 0
    spacing: 8
    // Re-push service values (e.g. after Clear): user typing breaks the
    // text binding, so service-driven changes are re-applied here.
    onInitialChanged: tf.text = initial
    Text {
      text: parent.label; textFormat: Text.PlainText
      width: 76
      color: Util.alpha(Color.foreground, 0.65)
      font.family: Style.fontFamily; font.pixelSize: 11
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }
    TextField {
      id: tf
      width: parent.width - 76 - 42 - parent.spacing * 2
      text: parent.initial
      placeholderText: parent.label
      onEditingFinished: { parent.commit(text); }
      onAccepted: { parent.commit(text); }
    }
    SheetAction {
      icon: "check"
      hint: "Set " + parent.label
      anchors.verticalCenter: parent.verticalCenter
      onTriggered: function() { parent.flush(); service.pokeStatus("Set " + parent.label + "."); }
    }
  }

  component DotRow: Row {
    property string label: ""
    property int value: 0
    property int max: 5
    signal dec()
    signal inc()
    width: parent ? parent.width : 0
    spacing: 6
    Text {
      text: parent.label; textFormat: Text.PlainText
      width: parent.width - 150
      color: Color.foreground
      font.family: Style.fontFamily; font.pixelSize: 11
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }
    WidgetButton { text: "−"; onPressed: function() { parent.dec(); } }
    Text {
      text: parent.value + "/" + parent.max; textFormat: Text.PlainText
      width: 40; horizontalAlignment: Text.AlignHCenter
      color: Color.accent
      font.family: Style.fontFamily; font.pixelSize: 11; font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
    WidgetButton { text: "+"; onPressed: function() { parent.inc(); } }
  }

  component MultiLine: Column {
    property string label: ""
    property string initial: ""
    signal commit(string value)
    // Same flush contract as FieldRow (see above).
    function flush() { commit(ta.text); }
    width: parent ? parent.width : 0
    spacing: 4
    // Same re-push as FieldRow (committing the identical value is a no-op).
    onInitialChanged: ta.text = initial
    Row {
      width: parent.width
      spacing: 6
      Text {
        text: parent.parent.label; textFormat: Text.PlainText
        width: parent.width - 42 - parent.spacing
        color: Util.alpha(Color.foreground, 0.65)
        font.family: Style.fontFamily; font.pixelSize: 11
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
      }
      SheetAction {
        icon: "check"
        hint: "Set " + parent.parent.label
        anchors.verticalCenter: parent.verticalCenter
        onTriggered: function() { flush(); service.pokeStatus("Set " + label + "."); }
      }
    }
    QQC.TextArea {
      id: ta
      width: parent.width
      text: parent.initial
      placeholderText: parent.label
      wrapMode: Text.Wrap
      font.family: Style.fontFamily; font.pixelSize: 11
      color: Color.foreground
      selectionColor: Color.accent
      background: Rectangle {
        color: Util.alpha(Color.foreground, 0.05)
        border.width: 1
        border.color: Util.alpha(Color.foreground, 0.15)
        radius: 8
      }
      onTextChanged: { parent.commit(text); }
    }
  }
}
