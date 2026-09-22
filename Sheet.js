.pragma library

// Field lists + plain-text renderer shared by SheetService.qml.
// Output format mirrors ~/Pictures/werewolf_sheet.py render().

function identityKeys() {
    return ["charName", "player", "chronicle", "concept", "nature", "demeanor",
            "breed", "auspice", "tribe", "rank", "packName", "packTotem", "sept"];
}

function identityLabels() {
    return {
        charName: "Name", player: "Player", chronicle: "Chronicle",
        concept: "Concept", nature: "Nature", demeanor: "Demeanor",
        breed: "Breed", auspice: "Auspice", tribe: "Tribe",
        rank: "Rank", packName: "Pack Name", packTotem: "Pack Totem",
        sept: "Sept / Caern"
    };
}

function attributeGroups() {
    return [
        { cat: "Physical", keys: ["str", "dex", "sta"], labels: ["Strength", "Dexterity", "Stamina"] },
        { cat: "Social", keys: ["cha", "man", "app"], labels: ["Charisma", "Manipulation", "Appearance"] },
        { cat: "Mental", keys: ["per", "intl", "wit"], labels: ["Perception", "Intelligence", "Wits"] }
    ];
}

function abilityGroups() {
    return [
        { cat: "Talents",
          keys: ["alertness", "athletics", "brawl", "empathy", "expression", "intimidation", "leadership", "primalUrge", "streetwise", "subterfuge"],
          labels: ["Alertness", "Athletics", "Brawl", "Empathy", "Expression", "Intimidation", "Leadership", "Primal-Urge", "Streetwise", "Subterfuge"] },
        { cat: "Skills",
          keys: ["animalKen", "crafts", "drive", "etiquette", "firearms", "larceny", "melee", "performance", "stealth", "survival"],
          labels: ["Animal Ken", "Crafts", "Drive", "Etiquette", "Firearms", "Larceny", "Melee", "Performance", "Stealth", "Survival"] },
        { cat: "Knowledges",
          keys: ["academics", "computer", "enigmas", "investigation", "law", "medicine", "occult", "rituals", "science", "technology"],
          labels: ["Academics", "Computer", "Enigmas", "Investigation", "Law", "Medicine", "Occult", "Rituals", "Science", "Technology"] }
    ];
}

function poolKeys() {
    return ["glory", "honor", "wisdom", "rage", "gnosis", "willpower", "experience"];
}

function poolLabels() {
    return { glory: "Glory", honor: "Honor", wisdom: "Wisdom", rage: "Rage",
             gnosis: "Gnosis", willpower: "Willpower", experience: "Experience" };
}

function textKeys() {
    return ["backgrounds", "gifts", "rites", "fetishes", "merits", "flaws",
            "gear", "history", "appearance", "personality", "goals", "ooc"];
}

function textLabels() {
    return { backgrounds: "Backgrounds", gifts: "Gifts", rites: "Rites",
             fetishes: "Fetishes", merits: "Merits", flaws: "Flaws",
             gear: "Gear / Equipment", history: "History", appearance: "Appearance",
             personality: "Personality", goals: "Goals",
             ooc: "OOC Instructions to LLM" };
}

function defaultData() {
    // True blank sheet: empty fields, Attributes 1 (WTA20 minimum),
    // all Abilities and pools 0.
    return {
        charName: "", player: "", chronicle: "", concept: "", nature: "", demeanor: "",
        breed: "", auspice: "", tribe: "", rank: "",
        packName: "", packTotem: "", sept: "",
        str: 1, dex: 1, sta: 1, cha: 1, man: 1, app: 1, per: 1, intl: 1, wit: 1,
        alertness: 0, athletics: 0, brawl: 0, empathy: 0, expression: 0,
        intimidation: 0, leadership: 0, primalUrge: 0, streetwise: 0, subterfuge: 0,
        animalKen: 0, crafts: 0, drive: 0, etiquette: 0, firearms: 0,
        larceny: 0, melee: 0, performance: 0, stealth: 0, survival: 0,
        academics: 0, computer: 0, enigmas: 0, investigation: 0, law: 0,
        medicine: 0, occult: 0, rituals: 0, science: 0, technology: 0,
        glory: 0, honor: 0, wisdom: 0, rage: 0, gnosis: 0, willpower: 0, experience: 0,
        backgrounds: "", gifts: "", rites: "", fetishes: "", merits: "", flaws: "",
        gear: "", history: "", appearance: "", personality: "", goals: "", ooc: ""
    };
}

function clampDot(v) {
    var n = parseInt(v, 10);
    if (!isFinite(n)) return 0;
    return Math.max(0, Math.min(5, n));
}

function clampPool(v) {
    var n = parseInt(v, 10);
    if (!isFinite(n)) return 0;
    return Math.max(0, Math.min(10, n));
}

// Valid [lo, hi] range per numeric data key, mirroring the +/- limits in
// SheetWindow.qml. Used by the service to clamp hand-edited JSON on load
// so crafted files cannot inject out-of-range values into the UI/export.
function limits() {
    var lim = {};
    var ag = attributeGroups();
    for (var g = 0; g < ag.length; g++)
        for (var j = 0; j < ag[g].keys.length; j++)
            lim[ag[g].keys[j]] = [0, 5];
    var bg = abilityGroups();
    for (var h = 0; h < bg.length; h++)
        for (var k = 0; k < bg[h].keys.length; k++)
            lim[bg[h].keys[k]] = [0, 5];
    var pk = poolKeys();
    for (var p = 0; p < pk.length; p++)
        lim[pk[p]] = [0, 10];
    return lim;
}

function bulletBlock(s) {
    var lines = String(s || "").split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var t = lines[i].replace(/^\s+|\s+$/g, "");
        if (t !== "") out.push("  - " + t);
    }
    if (!out.length) out.push("  - ");
    return out.join("\n");
}

function renderText(d) {
    var L = [];
    var labels = identityLabels();
    var keys = identityKeys();
    L.push("WEREWOLF: THE APOCALYPSE 20th - CHARACTER SHEET (Plain Text for LLM)");
    L.push("======================================================================");
    L.push("");
    L.push("== IDENTITY ==");
    for (var i = 0; i < keys.length; i++)
        L.push(labels[keys[i]] + ": " + (d[keys[i]] !== undefined ? d[keys[i]] : ""));
    L.push("");
    L.push("== ATTRIBUTES ==");
    var ag = attributeGroups();
    for (var g = 0; g < ag.length; g++) {
        L.push(ag[g].cat + ":");
        for (var j = 0; j < ag[g].keys.length; j++)
            L.push("  " + ag[g].labels[j] + ": " + (d[ag[g].keys[j]] || 0) + "/5");
    }
    L.push("");
    L.push("== ABILITIES ==");
    var bg = abilityGroups();
    for (var h = 0; h < bg.length; h++) {
        L.push(bg[h].cat + ":");
        for (var k = 0; k < bg[h].keys.length; k++)
            L.push("  " + bg[h].labels[k] + ": " + (d[bg[h].keys[k]] || 0) + "/5");
    }
    L.push("");
    L.push("== ADVANTAGES ==");
    var tl = textLabels();
    var order = ["backgrounds", "gifts", "rites", "fetishes", "merits", "flaws"];
    for (var m = 0; m < order.length; m++) {
        L.push(tl[order[m]] + ":");
        L.push(bulletBlock(d[order[m]]));
        L.push("");
    }
    L.push("== RENOWN / POOLS ==");
    var pl = poolLabels();
    var pk = poolKeys();
    for (var p = 0; p < pk.length; p++)
        L.push(pl[pk[p]] + ": " + (d[pk[p]] !== undefined ? d[pk[p]] : 0));
    L.push("");
    L.push("Health: [ ] Bruised, [ ] Hurt(-1), [ ] Injured(-1), [ ] Wounded(-2), [ ] Mauled(-2), [ ] Crippled(-5), [ ] Incapacitated");
    L.push("");
    L.push("== FORMS REFERENCE ==");
    L.push("Homid: No change. No Delirium. Diff 6.");
    L.push("Glabro: Str +2, Sta +2, Man -2, App -1. Diff 7.");
    L.push("Crinos: Str +4, Dex +1, Sta +3, Man -3, App 0. Diff 6. Full Delirium.");
    L.push("Hispo: Str +3, Dex +2, Sta +3, Man -3. Diff 7.");
    L.push("Lupus: Str +1, Dex +2, Sta +2, Man -3. Diff 6.");
    L.push("");
    L.push("== DESCRIPTION / ROLEPLAY ==");
    var dk = ["gear", "history", "appearance", "personality", "goals", "ooc"];
    for (var q = 0; q < dk.length; q++) {
        L.push(tl[dk[q]] + ":");
        L.push(bulletBlock(d[dk[q]]));
    }
    L.push("");
    L.push("== LLM INSTRUCTIONS ==");
    var nm = d.charName && String(d.charName).length ? d.charName : "this character";
    L.push("'You are the Storyteller for Werewolf: The Apocalypse 20th. I play " + nm + ". Use this sheet for stats. Call for rolls like Dexterity+Stealth (diff X). Track Rage/Gnosis/Willpower/Health. Roleplay NPCs, don't godmode my PC.'");
    L.push("======================================================================");
    return L.join("\n") + "\n";
}

// Unique per-character file name, e.g. "Mara-Breaks-the-Chain.txt".
function sheetFileName(d) {
    var base = d && d.charName ? String(d.charName).replace(/^\s+|\s+$/g, "") : "";
    if (base === "") base = "unnamed-werewolf";
    base = base.replace(/\s+/g, "-").replace(/[^A-Za-z0-9-_]/g, "-")
               .replace(/-+/g, "-").replace(/^-+|-+$/g, "");
    if (base === "") base = "unnamed-werewolf";
    if (base.length > 80) base = base.slice(0, 80);
    return base + ".txt";
}

// Parse an exported plain-text sheet back into a data object.
// Tolerant: skips unknown lines, accepts legacy "Nature / Demeanor" line.
function parseText(text) {
    var d = defaultData();
    var warnings = [];
    var labelToIdentity = {};
    var ik = identityKeys(), il = identityLabels();
    for (var i = 0; i < ik.length; i++) labelToIdentity[il[ik[i]]] = ik[i];
    labelToIdentity["Nature / Demeanor"] = "nature"; // legacy combined line
    var attrMap = {};
    var ag = attributeGroups();
    for (var g = 0; g < ag.length; g++)
        for (var j = 0; j < ag[g].keys.length; j++)
            attrMap[ag[g].labels[j].toLowerCase()] = { key: ag[g].keys[j], max: 5 };
    var bg = abilityGroups();
    for (var h = 0; h < bg.length; h++)
        for (var k = 0; k < bg[h].keys.length; k++)
            attrMap[bg[h].labels[k].toLowerCase()] = { key: bg[h].keys[k], max: 5 };
    var poolMap = {};
    var pl = poolLabels();
    for (var pk in pl) poolMap[pl[pk].toLowerCase()] = pk;
    var textMap = {};
    var tl = textLabels();
    for (var tk in tl) textMap[tl[tk].toLowerCase()] = tk;

    var lines = String(text || "").split("\n");
    var section = "";
    var currentList = null;
    for (var n = 0; n < lines.length; n++) {
        var t = lines[n].replace(/^\s+|\s+$/g, "");
        if (t === "") { currentList = null; continue; }
        if (t.indexOf("==") === 0) { section = t.toUpperCase(); currentList = null; continue; }
        var m;
        if (section.indexOf("IDENTITY") >= 0) {
            m = t.match(/^([^:]+):\s*(.*)$/);
            if (m) {
                var key = labelToIdentity[m[1].replace(/^\s+|\s+$/g, "")];
                if (key) d[key] = m[2].replace(/^\s+|\s+$/g, "");
            }
            continue;
        }
        if (section.indexOf("ATTRIBUTES") >= 0 || section.indexOf("ABILITIES") >= 0) {
            m = t.match(/^(.+?):\s*(\d+)\s*\/\s*5\s*$/);
            if (m) {
                var spec = attrMap[m[1].replace(/^\s+|\s+$/g, "").toLowerCase()];
                if (spec) {
                    var v = parseInt(m[2], 10);
                    d[spec.key] = Math.max(0, Math.min(spec.max, isFinite(v) ? v : 0));
                }
            }
            continue;
        }
        if (section.indexOf("RENOWN") >= 0 || section.indexOf("POOLS") >= 0) {
            m = t.match(/^([^:]+):\s*(\d+)/);
            if (m) {
                var pk2 = poolMap[m[1].replace(/^\s+|\s+$/g, "").toLowerCase()];
                if (pk2) {
                    var v2 = parseInt(m[2], 10);
                    d[pk2] = Math.max(0, Math.min(10, isFinite(v2) ? v2 : 0));
                }
            }
            continue;
        }
        if (section.indexOf("ADVANTAGES") >= 0 || section.indexOf("DESCRIPTION") >= 0) {
            m = t.match(/^([^:]+):\s*(.*)$/);
            if (m && textMap[m[1].replace(/^\s+|\s+$/g, "").toLowerCase()] !== undefined) {
                currentList = textMap[m[1].replace(/^\s+|\s+$/g, "").toLowerCase()];
                d[currentList] = m[2].replace(/^\s+|\s+$/g, "");
                continue;
            }
            if (currentList) {
                var b = t.match(/^-\s?(.*)$/);
                if (b) {
                    if (d[currentList] !== "") d[currentList] += "\n";
                    d[currentList] += b[1];
                }
            }
            continue;
        }
    }
    var tks = textKeys();
    for (var q = 0; q < tks.length; q++) {
        var parts = String(d[tks[q]] || "").split("\n");
        var kept = [];
        for (var r = 0; r < parts.length; r++) {
            var pv = parts[r].replace(/^\s+|\s+$/g, "");
            if (pv !== "" && pv !== "-") kept.push(pv);
        }
        d[tks[q]] = kept.join("\n");
    }
    if ((d.charName || "") === "") warnings.push("No character name found — check the file is an exported sheet.");
    return { data: d, warnings: warnings };
}
