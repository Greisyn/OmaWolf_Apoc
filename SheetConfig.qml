import QtQuick
import Quickshell
import Quickshell.Io

// UI prefs + output path. Bar-icon-driven sheet card (no floating anchor):
// corner/margin/size place the card, or drag the card header to float it
// anywhere (placeMode free + posX/posY persist the drop). keepOpen pins it
// so X cannot close.
// Legacy anchor keys (showAnchor, anchorMode, freeX/freeY, anchorLocked,
// buttonSize, openDelay, closeDelay) are still read/written so old prefs
// files keep loading, but nothing on screen uses them anymore.
// Persists to ~/.config/omarchy/local.werewolf-sheet.json
Item {
  id: root
  visible: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/local.werewolf-sheet.json"

  // legacy: floating square anchor (removed — bar icon only now).
  // Kept so existing prefs JSON still parses; always written as false.
  property bool showAnchor: false
  // legacy anchor placement (unused)
  property string anchorMode: "corner" // corner | free
  // card corner snap: topLeft | topRight | bottomLeft | bottomRight
  property string corner: "topRight"
  property int cornerMarginX: 24
  property int cornerMarginY: 24
  // card placement: corner snap or free (drag the card header anywhere;
  // drop position persists as card top-left screen fractions 0..1)
  property string placeMode: "corner" // corner | free
  property real posX: 0.55
  property real posY: 0.12
  // legacy free-floating square center, as screen fractions (0..1, unused)
  property real freeX: 0.90
  property real freeY: 0.12
  // legacy lock (unused)
  property bool anchorLocked: false
  // legacy square size (unused)
  property int buttonSize: 52
  // card size (minimum 600 x 550 so the 3-column abilities fit)
  property int sideWidth: 600
  property int sideHeight: 660
  // pin: X / Esc / bar-toggle / IPC-hide cannot close while true
  property bool keepOpen: false

  // --- Timing & motion (open/close dwell delays are legacy, unused) ---
  property int openDelay: 300
  property int closeDelay: 900
  property int motionDuration: 240
  property bool reducedMotion: false

  // output folder: exports are named per character (<Name>.txt)
  property string outputDir: home + "/Pictures"
  // last used import file (persisted so IPC import works headless)
  property string importPath: ""

  property bool loaded: false
  property string lastWritten: ""

  function defaults() {
    return {
      showAnchor: false, anchorMode: "corner", corner: "topRight",
      placeMode: "corner", posX: 0.55, posY: 0.12,
      cornerMarginX: 24, cornerMarginY: 24,
      freeX: 0.90, freeY: 0.12, anchorLocked: false,
      buttonSize: 52, sideWidth: 600, sideHeight: 660, keepOpen: false,
      openDelay: 300, closeDelay: 900,
      motionDuration: 240, reducedMotion: false,
      outputDir: root.home + "/Pictures", importPath: ""
    };
  }

  function clampNum(v, lo, hi, fallback) {
    var n = Number(v);
    if (!isFinite(n)) n = fallback;
    return Math.round(Math.max(lo, Math.min(hi, n)));
  }

  function load(raw) {
    var d = root.defaults();
    var p = {};
    try { p = JSON.parse(String(raw || "{}")); } catch (e) { p = {}; }
    if (["topLeft", "topRight", "bottomLeft", "bottomRight"].indexOf(p.corner) >= 0)
      d.corner = p.corner;
    if (p.placeMode === "free" || p.placeMode === "corner") d.placeMode = p.placeMode;
    if (isFinite(Number(p.posX))) d.posX = Math.max(0, Math.min(1, Number(p.posX)));
    if (isFinite(Number(p.posY))) d.posY = Math.max(0, Math.min(1, Number(p.posY)));
    if (p.anchorMode === "free" || p.anchorMode === "corner") d.anchorMode = p.anchorMode;
    if (typeof p.showAnchor === "boolean") d.showAnchor = p.showAnchor;
    if (typeof p.anchorLocked === "boolean") d.anchorLocked = p.anchorLocked;
    if (isFinite(Number(p.freeX))) d.freeX = Math.max(0.02, Math.min(0.98, Number(p.freeX)));
    if (isFinite(Number(p.freeY))) d.freeY = Math.max(0.02, Math.min(0.98, Number(p.freeY)));
    d.buttonSize = root.clampNum(p.buttonSize, 40, 96, d.buttonSize);
    d.cornerMarginX = root.clampNum(p.cornerMarginX, 0, 200, d.cornerMarginX);
    d.cornerMarginY = root.clampNum(p.cornerMarginY, 0, 200, d.cornerMarginY);
    d.sideWidth = root.clampNum(p.sideWidth, 600, 700, d.sideWidth);
    d.sideHeight = root.clampNum(p.sideHeight, 550, 1000, d.sideHeight);
    d.openDelay = root.clampNum(p.openDelay, 0, 1500, d.openDelay);
    d.closeDelay = root.clampNum(p.closeDelay, 250, 3000, d.closeDelay);
    d.motionDuration = root.clampNum(p.motionDuration, 0, 600, d.motionDuration);
    ["reducedMotion", "keepOpen"].forEach(function(k) {
      if (typeof p[k] === "boolean") d[k] = p[k];
    });
    if (typeof p.outputDir === "string" && p.outputDir.length > 0) {
      d.outputDir = p.outputDir;
    } else if (typeof p.outputPath === "string" && p.outputPath.length > 0) {
      // migrate legacy file path -> its folder
      var v = p.outputPath;
      var slash = v.lastIndexOf("/");
      d.outputDir = slash > 0 ? v.slice(0, slash) : root.home + "/Pictures";
    }
    if (typeof p.importPath === "string") d.importPath = p.importPath;

    root.showAnchor = false; // anchor removed: bar icon only, always
    root.anchorMode = "corner"; // anchor removed: card always corner-snapped
    root.freeX = d.freeX; root.freeY = d.freeY;
    root.anchorLocked = d.anchorLocked;
    root.corner = d.corner;
    root.placeMode = d.placeMode;
    root.posX = d.posX; root.posY = d.posY;
    root.cornerMarginX = d.cornerMarginX; root.cornerMarginY = d.cornerMarginY;
    root.buttonSize = d.buttonSize;
    root.sideWidth = d.sideWidth; root.sideHeight = d.sideHeight;
    root.keepOpen = d.keepOpen;
    root.openDelay = d.openDelay; root.closeDelay = d.closeDelay;
    root.motionDuration = d.motionDuration; root.reducedMotion = d.reducedMotion;
    root.outputDir = d.outputDir;
    root.importPath = d.importPath;
    root.loaded = true;
  }

  function snapshot() {
    return {
      showAnchor: root.showAnchor, anchorMode: root.anchorMode, corner: root.corner,
      placeMode: root.placeMode, posX: root.posX, posY: root.posY,
      cornerMarginX: root.cornerMarginX, cornerMarginY: root.cornerMarginY,
      freeX: root.freeX, freeY: root.freeY, anchorLocked: root.anchorLocked,
      buttonSize: root.buttonSize,
      sideWidth: root.sideWidth, sideHeight: root.sideHeight,
      keepOpen: root.keepOpen, openDelay: root.openDelay, closeDelay: root.closeDelay,
      motionDuration: root.motionDuration, reducedMotion: root.reducedMotion,
      outputDir: root.outputDir, importPath: root.importPath
    };
  }

  function save() {
    if (!root.loaded) return;
    var text = JSON.stringify(root.snapshot(), null, 2) + "\n";
    root.lastWritten = text;
    settingsFile.setText(text);
  }

  function set(key, value) {
    if (root[key] === value) return;
    root[key] = value;
    saveTimer.restart();
  }

  function resetAll() {
    var d = root.defaults();
    for (var k in d) root[k] = d[k];
    saveTimer.restart();
  }

  Timer { id: saveTimer; interval: 250; repeat: false; onTriggered: root.save() }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: settingsFile.reload()
    onLoaded: {
      if (text() === root.lastWritten && root.loaded) return;
      root.load(text());
    }
    onLoadFailed: root.load("")
  }

  Component.onCompleted: settingsFile.reload()
}
