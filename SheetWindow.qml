pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Bar-icon-driven floating sheet editor (no floating square anchor).
// Open/close from the bar icon (left-click), IPC (show/hide/toggle), the
// card's X button, or Esc. No hover-dwell, no auto-collapse on mouse leave:
// the card stays open until explicitly closed. Pin (keepOpen) blocks every
// close path (X, Esc, bar toggle, IPC hide) until unpinned.
// Only the open card takes input; all other pixels pass through to the
// desktop via the layer-shell input mask.
// All colors via Color.* / Style.* so omarchy themes repaint it live.
PanelWindow {
  id: root
  required property var service
  required property var cfg

  readonly property bool atRight: cfg.corner === "topRight" || cfg.corner === "bottomRight"
  readonly property bool atBottom: cfg.corner === "bottomLeft" || cfg.corner === "bottomRight"
  readonly property real topClearance: 44 // keep clear of the top bar
  readonly property bool reducedMotion: cfg.reducedMotion
  property bool expanded: false
  property real openness: expanded ? 1 : 0
  readonly property real cardW: Math.min(width - 32, cfg.sideWidth)
  readonly property real cardH: Math.min(height - 32, cfg.sideHeight)
  // live drag offset (pixels from press origin while dragging the header)
  property real dragDX: 0
  property real dragDY: 0
  readonly property bool dragging: dragHandler.active
  // card position: corner snap, or free placement (drag the header —
  // position persists in cfg.posX/posY as screen fractions)
  readonly property real cornerCardX: {
    var cx = atRight ? width - cardW - cfg.cornerMarginX : cfg.cornerMarginX;
    return Math.max(16, Math.min(width - cardW - 16, cx));
  }
  readonly property real cornerCardY: {
    var cy = atBottom ? height - cardH - cfg.cornerMarginY - 16
      : cfg.cornerMarginY + topClearance + 16;
    return Math.max(16, Math.min(height - cardH - 16, cy));
  }
  readonly property real cardX: {
    if (cfg.placeMode !== "free") return cornerCardX;
    return Math.max(16, Math.min(width - cardW - 16, cfg.posX * width + (dragging ? dragDX : 0)));
  }
  readonly property real cardY: {
    if (cfg.placeMode !== "free") return cornerCardY;
    return Math.max(16, Math.min(height - cardH - 16, cfg.posY * height + (dragging ? dragDY : 0)));
  }

  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "werewolf-sheet"
  WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region {
    x: surface.x; y: surface.y
    width: root.expanded ? surface.width : 0; height: surface.height
    radius: surface.radius
  }

  Behavior on openness {
    NumberAnimation {
      duration: root.reducedMotion ? 0 : root.expanded ? cfg.motionDuration : Math.round(cfg.motionDuration * 0.75)
      easing.type: Easing.OutCubic
    }
  }

  function reveal() {
    if (expanded) return;
    expanded = true;
    content.forceActiveFocus();
  }
  // Explicit close only (X button, Esc, bar-icon toggle, IPC hide).
  // Pin (keepOpen) blocks it — unpin first.
  function collapse() {
    if (cfg.keepOpen) return;
    expanded = false;
  }
  function toggle() { expanded ? collapse() : reveal(); }
  // Drop the card after a header drag: persist the free position (screen
  // fractions, clamped 0..1 — on-screen clamping happens in cardX/cardY).
  function commitCardDrag() {
    var fx = (cfg.posX * width + root.dragDX) / width;
    var fy = (cfg.posY * height + root.dragDY) / height;
    root.dragDX = 0; root.dragDY = 0;
    cfg.set("posX", Math.max(0, Math.min(1, fx)));
    cfg.set("posY", Math.max(0, Math.min(1, fy)));
  }
  // ---- field search ----
  // Live-dims rows whose label matches neither the query nor their section
  // (so "stealth" finds Stealth, "talent" finds the whole TALENTS group).
  // Enter jumps through matches (Shift+Enter backwards) with a highlight
  // flash; Esc clears the query first instead of closing the card.
  property var searchHits: []
  property int searchIndex: -1
  function applySearch() {
    var q = searchField.text.trim().toLowerCase();
    var st = { sec: "", sub: "", secMatch: {}, hits: [], headers: [] };
    walkSearch(body, q, st);
    for (var j = 0; j < st.headers.length; j++) {
      var h = st.headers[j];
      var t = String(h.text).toLowerCase();
      h.searchDim = !(q === "" || t.indexOf(q) >= 0 || st.secMatch[t] === true);
    }
    root.searchHits = st.hits;
    root.searchIndex = -1;
    matchCount.text = q === "" ? "" : (st.hits.length === 0 ? "0" : String(st.hits.length));
  }
  // In-order walk of the sheet rows. Descends into containers (the
  // 3-column Attributes / Abilities Rows) so nested rows and their
  // sub-headers take part. Tracks two levels: the sheet section (level 0:
  // Identity, Attributes, Abilities, ...) and the sub title inside it
  // (level 1: Physical, Talents, ...). A row matches when its label, its
  // sub title, or its section contains the query.
  function walkSearch(item, q, st) {
    var kids = item ? item.children : null;
    if (!kids) return;
    for (var i = 0; i < kids.length; i++) {
      var it = kids[i];
      if (!it) continue;
      if (it.isSectionHeader === true) {
        var t = String(it.text).toLowerCase();
        if ((it.headerLevel || 0) === 0) { st.sec = t; st.sub = ""; }
        else { st.sub = t; }
        st.headers.push(it);
      } else if (("searchMatch" in it)) {
        var lab = String(it.label || "").toLowerCase();
        var m = (q === "") || (lab.indexOf(q) >= 0)
          || (st.sub !== "" && st.sub.indexOf(q) >= 0)
          || (st.sec !== "" && st.sec.indexOf(q) >= 0);
        it.searchMatch = m;
        if (m && q !== "") {
          st.hits.push(it);
          if (st.sub !== "") st.secMatch[st.sub] = true;
          if (st.sec !== "") st.secMatch[st.sec] = true;
        }
      }
      if (it.children && it.children.length > 0) walkSearch(it, q, st);
    }
  }
  function jumpSearch(dir) {
    var hits = root.searchHits;
    if (hits.length === 0) return;
    root.searchIndex = (((root.searchIndex + dir) % hits.length) + hits.length) % hits.length;
    var it = hits[root.searchIndex];
    if (!it) return;
    // body sits at the Flickable content origin, so body coords are
    // content coords (nested rows need mapToItem, not raw y).
    var p = it.mapToItem(body, 0, 0);
    searchGlow.x = p.x;
    searchGlow.y = p.y;
    searchGlow.width = it.width;
    searchGlow.height = it.height;
    searchGlow.opacity = 1;
    glowTimer.restart();
    var target = p.y - 48;
    var maxY = Math.max(0, scroller.contentHeight - scroller.height);
    scroller.contentY = Math.max(0, Math.min(maxY, target));
    matchCount.text = (root.searchIndex + 1) + "/" + hits.length;
  }
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
  // Refresh the import path each time the card opens so it tracks the
  // current output folder instead of going stale after settings edits.
  onExpandedChanged: { if (expanded) importField.text = cfg.outputDir + "/"; }

  Timer { id: glowTimer; interval: 1200; repeat: false; onTriggered: { searchGlow.opacity = 0; searchGlow.height = 0; } }

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

    Rectangle {
      anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
      height: Math.min(parent.height, 120); radius: 23
      gradient: Gradient {
        GradientStop { position: 0; color: Util.alpha(Color.accent, 0.08) }
        GradientStop { position: 1; color: "transparent" }
      }
    }

    // Drag handle: the header strip (above the scroll body at y 96).
    // Grab empty header space to move the card anywhere on the workspace;
    // the drop position persists. Pin/close buttons and fields below sit
    // in later siblings, so their clicks still win on their own pixels.
    Item {
      id: dragHandle
      x: 0; y: 0; width: parent.width; height: 96
      HoverHandler {
        id: dragHover
        cursorShape: dragHandler.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      }
      DragHandler {
        id: dragHandler
        target: null
        onActiveChanged: {
          if (active) {
            root.dragDX = 0; root.dragDY = 0;
            // Seed free placement from the current corner spot so a first
            // drag off a snapped corner doesn't jump the card.
            if (cfg.placeMode !== "free") {
              cfg.set("posX", root.cornerCardX / root.width);
              cfg.set("posY", root.cornerCardY / root.height);
              cfg.set("placeMode", "free");
            }
          } else root.commitCardDrag();
        }
        onTranslationChanged: { root.dragDX = translation.x; root.dragDY = translation.y; }
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
        SheetAction { icon: "pin"; hint: cfg.keepOpen ? "Unpin (allow X to close)" : "Pin (X cannot close)"; selected: cfg.keepOpen; onTriggered: cfg.set("keepOpen", !cfg.keepOpen) }
        SheetAction { icon: "close"; hint: cfg.keepOpen ? "Pinned — unpin to close" : "Close sheet"; enabled: !cfg.keepOpen; onTriggered: root.collapse() }
      }

      Row {
        id: searchRow
        x: 16; y: 96; width: parent.width - 32
        spacing: 8
        TextField {
          id: searchField
          width: parent.width - matchCount.width - parent.spacing
          anchors.verticalCenter: parent.verticalCenter
          placeholderText: "Search fields… (Enter jumps, Esc clears)"
          onTextChanged: root.applySearch()
          Keys.onReturnPressed: function(event) {
            root.jumpSearch((event.modifiers & Qt.ShiftModifier) ? -1 : 1);
          }
          Keys.onEscapePressed: function(event) {
            if (text !== "") { text = ""; event.accepted = true; }
          }
        }
        Text {
          id: matchCount
          width: 44
          horizontalAlignment: Text.AlignRight
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          color: Util.alpha(Color.foreground, 0.55)
          font.family: Style.fontFamily; font.pixelSize: 11
        }
      }

      Flickable {
        id: scroller
        x: 16; y: searchRow.y + searchRow.height + 8; width: parent.width - 32; height: parent.height - (searchRow.y + searchRow.height + 8) - 64
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
          Row {
            width: parent.width
            spacing: 8
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "PHYSICAL" }
              DotCell { label: "Strength"; value: service.str; onDec: function() { service.bump("str", -1, 0, 5); } onInc: function() { service.bump("str", 1, 0, 5); } }
              DotCell { label: "Dexterity"; value: service.dex; onDec: function() { service.bump("dex", -1, 0, 5); } onInc: function() { service.bump("dex", 1, 0, 5); } }
              DotCell { label: "Stamina"; value: service.sta; onDec: function() { service.bump("sta", -1, 0, 5); } onInc: function() { service.bump("sta", 1, 0, 5); } }
            }
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "SOCIAL" }
              DotCell { label: "Charisma"; value: service.cha; onDec: function() { service.bump("cha", -1, 0, 5); } onInc: function() { service.bump("cha", 1, 0, 5); } }
              DotCell { label: "Manipulation"; value: service.man; onDec: function() { service.bump("man", -1, 0, 5); } onInc: function() { service.bump("man", 1, 0, 5); } }
              DotCell { label: "Appearance"; value: service.app; onDec: function() { service.bump("app", -1, 0, 5); } onInc: function() { service.bump("app", 1, 0, 5); } }
            }
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "MENTAL" }
              DotCell { label: "Perception"; value: service.per; onDec: function() { service.bump("per", -1, 0, 5); } onInc: function() { service.bump("per", 1, 0, 5); } }
              DotCell { label: "Intelligence"; value: service.intl; onDec: function() { service.bump("intl", -1, 0, 5); } onInc: function() { service.bump("intl", 1, 0, 5); } }
              DotCell { label: "Wits"; value: service.wit; onDec: function() { service.bump("wit", -1, 0, 5); } onInc: function() { service.bump("wit", 1, 0, 5); } }
            }
          }

          SectionSeparator { }
          SectionHeader { text: "ABILITIES" }
          // Abilities side by side: Talents | Skills | Knowledges.
          Row {
            width: parent.width
            spacing: 8
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "TALENTS" }
              DotCell { label: "Alertness"; value: service.alertness; onDec: function() { service.bump("alertness", -1, 0, 5); } onInc: function() { service.bump("alertness", 1, 0, 5); } }
              DotCell { label: "Athletics"; value: service.athletics; onDec: function() { service.bump("athletics", -1, 0, 5); } onInc: function() { service.bump("athletics", 1, 0, 5); } }
              DotCell { label: "Brawl"; value: service.brawl; onDec: function() { service.bump("brawl", -1, 0, 5); } onInc: function() { service.bump("brawl", 1, 0, 5); } }
              DotCell { label: "Empathy"; value: service.empathy; onDec: function() { service.bump("empathy", -1, 0, 5); } onInc: function() { service.bump("empathy", 1, 0, 5); } }
              DotCell { label: "Expression"; value: service.expression; onDec: function() { service.bump("expression", -1, 0, 5); } onInc: function() { service.bump("expression", 1, 0, 5); } }
              DotCell { label: "Intimidation"; value: service.intimidation; onDec: function() { service.bump("intimidation", -1, 0, 5); } onInc: function() { service.bump("intimidation", 1, 0, 5); } }
              DotCell { label: "Leadership"; value: service.leadership; onDec: function() { service.bump("leadership", -1, 0, 5); } onInc: function() { service.bump("leadership", 1, 0, 5); } }
              DotCell { label: "Primal-Urge"; value: service.primalUrge; onDec: function() { service.bump("primalUrge", -1, 0, 5); } onInc: function() { service.bump("primalUrge", 1, 0, 5); } }
              DotCell { label: "Streetwise"; value: service.streetwise; onDec: function() { service.bump("streetwise", -1, 0, 5); } onInc: function() { service.bump("streetwise", 1, 0, 5); } }
              DotCell { label: "Subterfuge"; value: service.subterfuge; onDec: function() { service.bump("subterfuge", -1, 0, 5); } onInc: function() { service.bump("subterfuge", 1, 0, 5); } }
            }
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "SKILLS" }
              DotCell { label: "Animal Ken"; value: service.animalKen; onDec: function() { service.bump("animalKen", -1, 0, 5); } onInc: function() { service.bump("animalKen", 1, 0, 5); } }
              DotCell { label: "Crafts"; value: service.crafts; onDec: function() { service.bump("crafts", -1, 0, 5); } onInc: function() { service.bump("crafts", 1, 0, 5); } }
              DotCell { label: "Drive"; value: service.drive; onDec: function() { service.bump("drive", -1, 0, 5); } onInc: function() { service.bump("drive", 1, 0, 5); } }
              DotCell { label: "Etiquette"; value: service.etiquette; onDec: function() { service.bump("etiquette", -1, 0, 5); } onInc: function() { service.bump("etiquette", 1, 0, 5); } }
              DotCell { label: "Firearms"; value: service.firearms; onDec: function() { service.bump("firearms", -1, 0, 5); } onInc: function() { service.bump("firearms", 1, 0, 5); } }
              DotCell { label: "Larceny"; value: service.larceny; onDec: function() { service.bump("larceny", -1, 0, 5); } onInc: function() { service.bump("larceny", 1, 0, 5); } }
              DotCell { label: "Melee"; value: service.melee; onDec: function() { service.bump("melee", -1, 0, 5); } onInc: function() { service.bump("melee", 1, 0, 5); } }
              DotCell { label: "Performance"; value: service.performance; onDec: function() { service.bump("performance", -1, 0, 5); } onInc: function() { service.bump("performance", 1, 0, 5); } }
              DotCell { label: "Stealth"; value: service.stealth; onDec: function() { service.bump("stealth", -1, 0, 5); } onInc: function() { service.bump("stealth", 1, 0, 5); } }
              DotCell { label: "Survival"; value: service.survival; onDec: function() { service.bump("survival", -1, 0, 5); } onInc: function() { service.bump("survival", 1, 0, 5); } }
            }
            Column {
              width: (parent.width - parent.spacing * 2) / 3
              spacing: 6
              SubHeader { text: "KNOWLEDGES" }
              DotCell { label: "Academics"; value: service.academics; onDec: function() { service.bump("academics", -1, 0, 5); } onInc: function() { service.bump("academics", 1, 0, 5); } }
              DotCell { label: "Computer"; value: service.computer; onDec: function() { service.bump("computer", -1, 0, 5); } onInc: function() { service.bump("computer", 1, 0, 5); } }
              DotCell { label: "Enigmas"; value: service.enigmas; onDec: function() { service.bump("enigmas", -1, 0, 5); } onInc: function() { service.bump("enigmas", 1, 0, 5); } }
              DotCell { label: "Investigation"; value: service.investigation; onDec: function() { service.bump("investigation", -1, 0, 5); } onInc: function() { service.bump("investigation", 1, 0, 5); } }
              DotCell { label: "Law"; value: service.law; onDec: function() { service.bump("law", -1, 0, 5); } onInc: function() { service.bump("law", 1, 0, 5); } }
              DotCell { label: "Medicine"; value: service.medicine; onDec: function() { service.bump("medicine", -1, 0, 5); } onInc: function() { service.bump("medicine", 1, 0, 5); } }
              DotCell { label: "Occult"; value: service.occult; onDec: function() { service.bump("occult", -1, 0, 5); } onInc: function() { service.bump("occult", 1, 0, 5); } }
              DotCell { label: "Rituals"; value: service.rituals; onDec: function() { service.bump("rituals", -1, 0, 5); } onInc: function() { service.bump("rituals", 1, 0, 5); } }
              DotCell { label: "Science"; value: service.science; onDec: function() { service.bump("science", -1, 0, 5); } onInc: function() { service.bump("science", 1, 0, 5); } }
              DotCell { label: "Technology"; value: service.technology; onDec: function() { service.bump("technology", -1, 0, 5); } onInc: function() { service.bump("technology", 1, 0, 5); } }
            }
          }

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

        // Jump highlight: floats above the rows (direct Flickable child so
        // the Column never repositions it), fades via glowTimer below.
        Rectangle {
          id: searchGlow
          width: body.width; height: 0
          radius: 8
          color: Util.alpha(Color.accent, 0.16)
          opacity: 0
          Behavior on opacity { NumberAnimation { duration: 250 } }
        }
      }

      Rectangle {
        x: 16; y: parent.height - 56; width: parent.width - 32; height: 1
        color: Util.alpha(Color.foreground, 0.075)
      }
      Text {
        x: 18; y: parent.height - 40; width: parent.width - 36
        text: cfg.keepOpen ? "Pinned — unpin to close · drag the header to move" : "Drag the header to move · X or Esc closes · pin blocks closing"
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
  // Sheet section title (Identity, Attributes, Abilities, ...): large,
  // with a rule underneath to section it off from its rows.
  component SectionHeader: Column {
    property bool isSectionHeader: true
    property int headerLevel: 0
    property bool searchDim: false
    property alias text: caption.text
    opacity: searchDim ? 0.35 : 1
    width: parent ? parent.width : 0
    spacing: 4
    Text {
      id: caption
      textFormat: Text.PlainText
      color: Color.accent
      font.family: Style.fontFamily
      font.pixelSize: 16
      font.bold: true
      font.letterSpacing: 1.2
    }
    Rectangle {
      width: parent.width; height: 2
      color: Util.alpha(Color.accent, 0.35)
    }
  }

  // Sub title inside a section (Physical / Social / Mental, Talents /
  // Skills / Knowledges): same accent style, a step smaller than sections.
  component SubHeader: Text {
    property bool isSectionHeader: true
    property int headerLevel: 1
    property bool searchDim: false
    opacity: searchDim ? 0.35 : 1
    textFormat: Text.PlainText
    color: Color.accent
    font.family: Style.fontFamily
    font.pixelSize: 12
    font.bold: true
    font.letterSpacing: 0.8
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
    // search: dimmed when the query matches neither label nor section
    property bool searchMatch: true
    opacity: searchMatch ? 1 : 0.22
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
    // search: dimmed when the query matches neither label nor section
    property bool searchMatch: true
    opacity: searchMatch ? 1 : 0.22
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

  // Compact dot cell for the 3-column abilities block (Talents | Skills |
  // Knowledges). Same data contract as DotRow, but tiny −/+ text hit areas
  // instead of full push-buttons so three columns fit the card.
  component DotCell: Row {
    property string label: ""
    property int value: 0
    property int max: 5
    // search: dimmed when the query matches neither label nor section
    property bool searchMatch: true
    opacity: searchMatch ? 1 : 0.22
    signal dec()
    signal inc()
    width: parent ? parent.width : 0
    spacing: 4
    Text {
      text: parent.label; textFormat: Text.PlainText
      width: parent.width - 62
      color: Color.foreground
      font.family: Style.fontFamily; font.pixelSize: 11
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
    }
    Text {
      text: parent.value; textFormat: Text.PlainText
      width: 18; horizontalAlignment: Text.AlignHCenter
      color: Color.accent
      font.family: Style.fontFamily; font.pixelSize: 11; font.bold: true
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      text: "−"; textFormat: Text.PlainText
      width: 16; horizontalAlignment: Text.AlignHCenter
      color: decMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.55)
      font.family: Style.fontFamily; font.pixelSize: 13; font.bold: true
      anchors.verticalCenter: parent.verticalCenter
      MouseArea { id: decMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.dec() }
    }
    Text {
      text: "+"; textFormat: Text.PlainText
      width: 16; horizontalAlignment: Text.AlignHCenter
      color: incMouse.containsMouse ? Color.accent : Util.alpha(Color.foreground, 0.55)
      font.family: Style.fontFamily; font.pixelSize: 13; font.bold: true
      anchors.verticalCenter: parent.verticalCenter
      MouseArea { id: incMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.inc() }
    }
  }

  component MultiLine: Column {
    property string label: ""
    property string initial: ""
    // search: dimmed when the query matches neither label nor section
    property bool searchMatch: true
    opacity: searchMatch ? 1 : 0.22
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
