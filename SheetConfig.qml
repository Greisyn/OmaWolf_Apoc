import QtQuick
import Quickshell
import Quickshell.Io

// UI prefs + output path. Mirrors local.disk-mounter DriveConfig.qml pattern:
// corner-anchored floating square anchor + card.
// Persists to ~/.config/omarchy/local.werewolf-sheet.json
Item {
  id: root
  visible: false

  readonly property string home: Quickshell.env("HOME")
  readonly property string settingsPath: home + "/.config/omarchy/local.werewolf-sheet.json"

  // floating square anchor (hideable; the bar icon can open the card instead)
  property bool showAnchor: true
  // anchor placement: corner snap or free-floating (drag the square)
  property string anchorMode: "corner" // corner | free
  // corner snap: topLeft | topRight | bottomLeft | bottomRight
  property string corner: "topRight"
  property int cornerMarginX: 24
  property int cornerMarginY: 24
  // free-floating square center, as screen fractions (0..1)
  property real freeX: 0.90
  property real freeY: 0.12
  // lock: disables dragging the square (corner buttons still snap it)
  property bool anchorLocked: false
  property int buttonSize: 52
  property int sideWidth: 430
  property int sideHeight: 660
  property bool keepOpen: false

  // --- Timing & motion ---
  property int openDelay: 300    // hover dwell on the square before reveal (ms)
  property int closeDelay: 900   // leave before collapse (ms)
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
      showAnchor: true, anchorMode: "corner", corner: "topRight",
      cornerMarginX: 24, cornerMarginY: 24,
      freeX: 0.90, freeY: 0.12, anchorLocked: false,
      buttonSize: 52, sideWidth: 430, sideHeight: 660, keepOpen: false,
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
    if (p.anchorMode === "free" || p.anchorMode === "corner") d.anchorMode = p.anchorMode;
    if (typeof p.showAnchor === "boolean") d.showAnchor = p.showAnchor;
    if (typeof p.anchorLocked === "boolean") d.anchorLocked = p.anchorLocked;
    if (isFinite(Number(p.freeX))) d.freeX = Math.max(0.02, Math.min(0.98, Number(p.freeX)));
    if (isFinite(Number(p.freeY))) d.freeY = Math.max(0.02, Math.min(0.98, Number(p.freeY)));
    d.buttonSize = root.clampNum(p.buttonSize, 40, 96, d.buttonSize);
    d.cornerMarginX = root.clampNum(p.cornerMarginX, 0, 200, d.cornerMarginX);
    d.cornerMarginY = root.clampNum(p.cornerMarginY, 0, 200, d.cornerMarginY);
    d.sideWidth = root.clampNum(p.sideWidth, 340, 700, d.sideWidth);
    d.sideHeight = root.clampNum(p.sideHeight, 420, 1000, d.sideHeight);
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

    root.showAnchor = d.showAnchor;
    root.anchorMode = d.anchorMode;
    root.freeX = d.freeX; root.freeY = d.freeY;
    root.anchorLocked = d.anchorLocked;
    root.corner = d.corner;
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
