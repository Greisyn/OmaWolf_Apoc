pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Sheet.js" as Sheet

// Owns character data, renders plain text (same format as werewolf_sheet.py),
// exports to the user-chosen output path, mounts one corner-anchored
// SheetWindow per screen. Theme-awareness lives in the windows (Color/Style).
Item {
  id: root
  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id) : "local.werewolf-sheet"

  SheetConfig { id: config }

  readonly property string home: Quickshell.env("HOME")
  readonly property string characterPath: home + "/.config/omarchy/local.werewolf-sheet-character.json"

  // ---- identity (blank sheet: everything empty) ----
  property string charName: ""
  property string player: ""
  property string chronicle: ""
  property string concept: ""
  property string nature: ""
  property string demeanor: ""
  property string breed: ""
  property string auspice: ""
  property string tribe: ""
  property string rank: ""
  property string packName: ""
  property string packTotem: ""
  property string sept: ""

  // ---- attributes: blank sheet = 1 (WTA20 minimum) ----
  property int str: 1; property int dex: 1; property int sta: 1
  property int cha: 1; property int man: 1; property int app: 1
  property int per: 1; property int intl: 1; property int wit: 1

  // ---- talents ----
  property int alertness: 0; property int athletics: 0; property int brawl: 0
  property int empathy: 0; property int expression: 0; property int intimidation: 0
  property int leadership: 0; property int primalUrge: 0; property int streetwise: 0
  property int subterfuge: 0
  // ---- skills ----
  property int animalKen: 0; property int crafts: 0; property int drive: 0
  property int etiquette: 0; property int firearms: 0; property int larceny: 0
  property int melee: 0; property int performance: 0; property int stealth: 0
  property int survival: 0
  // ---- knowledges ----
  property int academics: 0; property int computer: 0; property int enigmas: 0
  property int investigation: 0; property int law: 0; property int medicine: 0
  property int occult: 0; property int rituals: 0; property int science: 0
  property int technology: 0

  // ---- pools (blank sheet = 0) ----
  property int glory: 0; property int honor: 0; property int wisdom: 0
  property int rage: 0; property int gnosis: 0; property int willpower: 0
  property int experience: 0

  // ---- multiline texts ----
  property string backgrounds: ""
  property string gifts: ""
  property string rites: ""
  property string fetishes: ""
  property string merits: ""
  property string flaws: ""
  property string gear: ""
  property string history: ""
  property string appearance: ""
  property string personality: ""
  property string goals: ""
  property string ooc: ""

  property string status: "Ready"
  property bool dataLoaded: false
  property string lastSavedText: ""

  function snapshot() {
    var d = Sheet.defaultData();
    var keys = Object.keys(d);
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (root[k] !== undefined) d[k] = root[k];
    }
    return d;
  }

  function applyData(d) {
    if (!d || typeof d !== "object") return;
    var keys = Sheet.defaultData();
    for (var k in keys) {
      if (d[k] === undefined || root[k] === undefined) continue;
      if (typeof keys[k] === "number") {
        var n = parseInt(d[k], 10);
        root[k] = isFinite(n) ? n : keys[k];
      } else {
        root[k] = String(d[k]);
      }
    }
  }

  function renderText() {
    return Sheet.renderText(snapshot());
  }

  function bump(key, delta, lo, hi) {
    if (root[key] === undefined) return;
    var n = (parseInt(root[key], 10) || 0) + delta;
    n = Math.max(lo, Math.min(hi, n));
    root[key] = n;
    saveSoon();
  }

  // ---- persistence ----
  Timer { id: saveTimer; interval: 400; repeat: false; onTriggered: root.saveNow() }

  function saveSoon() {
    if (!root.dataLoaded) return;
    saveTimer.restart();
  }

  function saveNow() {
    if (!root.dataLoaded) return;
    var text = JSON.stringify(root.snapshot(), null, 2) + "\n";
    root.lastSavedText = text;
    root.writeFile(root.characterPath, text, saveWriter);
  }

  // Deterministic file writer (FileView.setText silently drops writes when
  // its path was just (re)assigned or the file is missing). Quoted heredoc:
  // literal content, no expansion; recreated on every call.
  function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
  }

  function expandPath(p) {
    var s = String(p || "");
    if (s === "" || s.charAt(0) !== "~") return s;
    if (s === "~") return root.home;
    if (s.indexOf("~/") === 0) return root.home + s.slice(1);
    return s;
  }

  function exportDir() {
    var d = root.expandPath(config.outputDir);
    if (d === "") d = root.home + "/Pictures";
    return d.replace(/\/+$/g, "");
  }

  function exportFileName() {
    return Sheet.sheetFileName(root.snapshot());
  }

  function exportFullPath() {
    return root.exportDir() + "/" + root.exportFileName();
  }

  function writeFile(path, text, proc) {
    proc.command = ["sh", "-c",
      "cat > " + root.shellQuote(path) + " <<'__WEREWOLF_SHEET_EOF__'\n" + text + "__WEREWOLF_SHEET_EOF__\n"];
    if (proc.running) proc.running = false;
    proc.running = true;
  }

  Process {
    id: saveWriter
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (this.text !== "") root.status = "Save error: " + this.text;
      }
    }
  }
  Process {
    id: exportWriter
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (this.text !== "") root.status = "Export error: " + this.text;
      }
    }
  }

  FileView {
    id: characterFile
    path: root.characterPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: characterFile.reload()
    onLoaded: {
      if (text() === root.lastSavedText && root.dataLoaded) return;
      try {
        var d = JSON.parse(String(text() || "{}"));
        root.applyData(d);
      } catch (e) { root.applyData(Sheet.defaultData()); }
      root.dataLoaded = true;
    }
    onLoadFailed: { root.applyData(Sheet.defaultData()); root.dataLoaded = true; }
  }

  // ---- export to output folder, file named per character ----
  function exportNow() {
    root.saveNow();
    var full = root.exportFullPath();
    root.writeFile(full, root.renderText(), exportWriter);
    root.status = "Exported to " + full;
    exportRinse.restart();
  }

  Timer { id: exportRinse; interval: 4000; repeat: false; onTriggered: root.status = "Ready" }

  function pokeStatus(msg) {
    root.status = msg;
    exportRinse.restart();
  }

  function copyForLLM() {    // Best-effort clipboard via wl-copy / xclip; export always works regardless.
    var txt = root.renderText().replace(/'/g, "'\\''");
    copyProc.command = ["sh", "-c", "printf '%s' '" + txt.slice(0, 60000) + "' | (wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null || true)"];
    copyProc.running = true;
    root.status = "Copied for LLM (if clipboard tool present). Export to file to be sure.";
    exportRinse.restart();
  }

  Process { id: copyProc }

  function clearSheet() {
    root.applyData(Sheet.defaultData());
    root.saveNow();
    root.status = "Sheet cleared.";
    exportRinse.restart();
  }

  // ---- import from an exported plain-text file ----
  property bool importArmed: false

  FileView {
    id: importer
    watchChanges: false
    atomicWrites: false
    printErrors: false
    onLoaded: {
      if (!root.importArmed) return;
      root.importArmed = false;
      root.doImportText(text());
    }
    onLoadFailed: {
      if (!root.importArmed) return;
      root.importArmed = false;
      root.status = "Import failed: cannot read file.";
      exportRinse.restart();
    }
  }

  function importSheet(path) {
    var p = (path === undefined || String(path).replace(/^\s+|\s+$/g, "") === "")
      ? config.importPath : String(path);
    p = root.expandPath(p.replace(/^\s+|\s+$/g, ""));
    if (p === "") {
      root.status = "Import: enter a plain-text sheet path first.";
      exportRinse.restart();
      return;
    }
    root.importArmed = true;
    importer.path = p;
    importer.reload();
  }

  function doImportText(text) {
    var res;
    try {
      res = Sheet.parseText(text);
    } catch (e) {
      root.status = "Import failed: could not parse file.";
      exportRinse.restart();
      return;
    }
    root.applyData(res.data);
    root.saveNow();
    var nm = res.data.charName && String(res.data.charName) !== "" ? res.data.charName : "sheet";
    root.status = "Imported " + nm + (res.warnings.length ? " (" + res.warnings[0] + ")" : "") + ".";
    exportRinse.restart();
  }

  Component.onCompleted: characterFile.reload()

  // ---- per-screen floating windows (cliamp-dock / oShelf model) ----
  Variants {
    id: windows
    model: Quickshell.screens
    SheetWindow {
      required property var modelData
      screen: modelData
      service: root
      cfg: config
    }
  }

  IpcHandler {
    target: root.pluginId
    function show(): string { for (var w of windows.instances) w.reveal(); return "shown"; }
    function hide(): string { for (var w2 of windows.instances) w2.collapse(); return "hidden"; }
    function toggle(): string {
      var any = false;
      for (var w3 of windows.instances) if (w3.expanded) { any = true; break; }
      if (any) { for (var w4 of windows.instances) w4.collapse(); return "hidden"; }
      for (var w5 of windows.instances) w5.reveal();
      return "shown";
    }
    function exportSheet(): string { root.exportNow(); return "exported to " + root.exportFullPath(); }
    function clear(): string { root.clearSheet(); return "cleared"; }
    function importSheet(): string { root.importSheet(); return "importing from " + config.importPath; }
    function status(): string {
      var states = [];
      for (var w of windows.instances) states.push(!!w.expanded);
      return JSON.stringify({ character: root.charName, output: root.exportFullPath(), expanded: states, status: root.status });
    }
  }
}
