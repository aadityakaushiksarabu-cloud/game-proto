#macro COL_BG make_color_rgb(7, 10, 18)
#macro COL_DECK make_color_rgb(42, 40, 38)
#macro COL_DECK2 make_color_rgb(28, 27, 26)
#macro COL_PANEL make_color_rgb(10, 16, 28)
#macro COL_HULL make_color_rgb(24, 36, 54)
#macro COL_HULL2 make_color_rgb(16, 24, 38)
#macro COL_LINE make_color_rgb(126, 214, 196)
#macro COL_DIML make_color_rgb(48, 72, 88)
#macro COL_TEXT make_color_rgb(220, 234, 230)
#macro COL_DIM make_color_rgb(118, 138, 146)
#macro COL_AMBER make_color_rgb(232, 178, 82)
#macro COL_RED make_color_rgb(216, 74, 74)
#macro COL_GREEN make_color_rgb(118, 196, 122)
#macro COL_O2 make_color_rgb(112, 196, 232)
#macro COL_FOOD make_color_rgb(154, 204, 96)
#macro COL_RAD make_color_rgb(220, 214, 92)
#macro COL_PWR make_color_rgb(240, 196, 78)

#macro START_O2 42
#macro START_FOOD 46
#macro START_WATER 100
#macro START_CARGO 98
#macro CREW_O2 0.84
#macro CREW_FOOD 1
#macro CREW_WATER 0.4
#macro SOLAR_KWH 56
#macro RTG_KWH 48
#macro BATT_KWH 120
#macro HAB_KWH 14
#macro FARM_KWH 12
#macro O2_KWH 18
#macro ICE_KWH 16
#macro MED_KWH 6
#macro COMMS_KWH 5
#macro SHELTER_KWH 6
#macro ICE_KG 14
#macro O2_WATER 4
#macro O2_YIELD 3.4
#macro FARM_WATER 4
#macro FARM_FOOD 7
#macro FARM_O2 0.4
#macro GCR_MSV 0.38
#macro DAY_LEN 16

function boot_game() {
    global.mode = "title";
    global.help = false;
    global.paused = false;
    global.spd = 1;
    global.acc = 0;
    global.day_len = DAY_LEN;
    global.epoch = "2026-09-16";
    global.sel = 4;
    global.crew_sel = -1;
    global.best = 0;
    global.points = 0;
    global.won = false;
    global.report = [];
    global.log = [];
    global.hits = [];
    global.ui_click = false;
    global.donki_dates = {};
    global.donki_seen = {};
    global.donki_flare_n = 0;
    global.donki_cme_n = 0;
    global.donki_sep_n = 0;
    global.donki_status = "NO CATALOG";
    global.donki_live = false;
    global.http_q = [];
    global.http_started = false;
    global.proton_carry = 0;
    global.comms_up = false;
    global.logged = 0;
    global.alert = false;
    global.today = { prompt: 0, proton: 0, fresh: 0, lines: [], significant: false, headline: "QUIET" };
    global.stars = [];
    global.craters = [];
    for (var i = 0; i < 110; i++) {
        array_push(global.stars, {
            x: (i * 97 + 13) mod 860,
            y: (i * 53 + 7) mod 520,
            r: 1 + (i mod 3),
            p: i * 0.7
        });
    }
    for (var c = 0; c < 18; c++) {
        array_push(global.craters, {
            x: 70 + (c * 73) mod 760,
            y: 110 + (c * 41) mod 400,
            r: 8 + (c mod 5) * 4
        });
    }
    kind_catalog();
    load_best();
    donki_load_snapshot();
    reset_run();
    if (!global.http_started) {
        global.http_started = true;
        donki_request_all();
    }
}

function kind_catalog() {
    global.kind_order = ["solar", "battery", "farm", "o2", "ice", "berm", "shelter", "med", "comms", "rtg"];
    global.kinds = {};
    global.kinds[$ "hab"] = { name: "HABITAT", label: "HAB", cost: 0, work: 0, max: 1, desc: "BUNKS AND THE SCRUBBER. KEEP THIS POWERED." };
    global.kinds[$ "airlock"] = { name: "DUSTLOCK", label: "LOCK", cost: 0, work: 0, max: 1, desc: "SUIT PORT. CREW HERE ARE STILL INDOORS." };
    global.kinds[$ "solar"] = { name: "SOLAR ARRAY", label: "SOLAR", cost: 8, work: 1, max: 3, desc: "POWER WHILE THE SUN IS UP. AN ENGINEER CLEARS DUST." };
    global.kinds[$ "battery"] = { name: "BATTERY BANK", label: "BATT", cost: 10, work: 2, max: 2, desc: "HOLDS SURPLUS DAYTIME POWER." };
    global.kinds[$ "farm"] = { name: "CALORIE FARM", label: "FARM", cost: 12, work: 2, max: 2, desc: "POTATO BEDS. FOUR DAYS TO FULL YIELD. NEEDS WATER." };
    global.kinds[$ "o2"] = { name: "OXYGENATOR", label: "O2", cost: 14, work: 2, max: 1, desc: "ELECTROLYSIS. 4 KG WATER MAKES 3.4 KG OXYGEN." };
    global.kinds[$ "ice"] = { name: "ICE EXTRACTOR", label: "ICE", cost: 10, work: 2, max: 1, desc: "PULLS BURIED ICE. FEEDS THE FARM AND THE OXYGENATOR." };
    global.kinds[$ "berm"] = { name: "REGOLITH BERM", label: "BERM", cost: 4, work: 2, max: 1, desc: "PASSIVE COVER. CUTS DOSE INSIDE THE STATION." };
    global.kinds[$ "shelter"] = { name: "STORM SHELTER", label: "SHELTER", cost: 16, work: 3, max: 1, desc: "THICK COVER FOR DONKI PROTON STORMS. HOLDS ALL CREW." };
    global.kinds[$ "med"] = { name: "MED BAY", label: "MED", cost: 8, work: 2, max: 1, desc: "RADIATION RECOVERY. STAFF IT WITH CHEN." };
    global.kinds[$ "comms"] = { name: "COMMS", label: "COMMS", cost: 5, work: 1, max: 1, desc: "LOCKS NASA DONKI. WITHOUT IT, STORMS ARRIVE QUIET." };
    global.kinds[$ "rtg"] = { name: "KILOPOWER", label: "KILO", cost: 18, work: 3, max: 1, desc: "CONSTANT POWER THROUGH THE FOURTEEN-DAY NIGHT." };
}

function reset_run() {
    global.day = 1;
    global.acc = 0;
    global.paused = false;
    global.spd = 1;
    global.o2 = START_O2;
    global.food = START_FOOD;
    global.water = START_WATER;
    global.cargo = START_CARGO;
    global.battery = 0;
    global.dust = 0.94;
    global.proton_carry = 0;
    global.comms_up = false;
    global.logged = 0;
    global.alert = false;
    global.points = 0;
    global.won = false;
    global.report = [];
    global.log = [];
    global.sel = 4;
    global.crew_sel = -1;
    global.pads = [];
    for (var r = 0; r < 3; r++) {
        for (var c = 0; c < 4; c++) {
            array_push(global.pads, {
                c: c, r: r, kind: "empty", phase: "empty",
                prog: 0, need: 0, want: true, on: false, ready_day: 0
            });
        }
    }
    var hab = 4;
    global.pads[hab].kind = "hab";
    global.pads[hab].phase = "ready";
    global.pads[hab].want = true;
    global.pads[hab].on = true;
    global.pads[hab].ready_day = 1;
    global.pads[5].kind = "airlock";
    global.pads[5].phase = "ready";
    global.pads[5].want = false;
    global.pads[5].on = true;
    global.pads[5].ready_day = 1;
    global.crew = [
        { name: "OKONKWO", role: "commander", short: "CDR", col: COL_AMBER, hp: 100, dose: 0, pad: hab, alive: true },
        { name: "VASQUEZ", role: "engineer", short: "ENG", col: make_color_rgb(232, 122, 72), hp: 100, dose: 0, pad: hab, alive: true },
        { name: "CHEN", role: "scientist", short: "SCI", col: COL_LINE, hp: 100, dose: 0, pad: hab, alive: true }
    ];
    global.today = { prompt: 0, proton: 0, fresh: 0, lines: [], significant: false, headline: "QUIET" };
    log_line("TOUCHDOWN. HAB AND DUSTLOCK ARE UP.");
    log_line("NIGHT FALLS ON DAY 12. SOLAR WILL NOT CARRY IT.");
    log_line("ASCENT WINDOW EVERY 5 DAYS. THAT FILES THE SCORE.");
}

function load_best() {
    global.best = 0;
    var ini_path = score_path();
    if (!file_exists(ini_path)) return;
    ini_open(ini_path);
    global.best = ini_read_real("run", "best", 0);
    ini_close();
}

function save_best(n) {
    if (n <= global.best) return;
    global.best = n;
    ini_open(score_path());
    ini_write_real("run", "best", n);
    ini_close();
}

function score_path() {
    var d = game_save_id;
    if (string_length(d) < 1) d = working_directory;
    var last = string_char_at(d, string_length(d));
    if (last != "/" && last != "\\") d += "/";
    return d + "lunar_hold.ini";
}

function log_line(s) {
    array_push(global.log, s);
    while (array_length(global.log) > 7) array_delete(global.log, 0, 1);
}

function num1(n) {
    var s = string_format(n, 0, 1);
    var out = "";
    var started = false;
    for (var i = 1; i <= string_length(s); i++) {
        var ch = string_char_at(s, i);
        if (ch != " " || started) {
            out += ch;
            started = true;
        }
    }
    if (string_length(out) < 1) return "0";
    return out;
}

function kind_info(k) {
    if (variable_struct_exists(global.kinds, k)) return global.kinds[$ k];
    return { name: "BAY", label: "BAY", cost: 0, work: 0, max: 99, desc: "OPEN PAD." };
}

function pad_count(kind, ready_only) {
    var n = 0;
    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        if (p.kind != kind) continue;
        if (ready_only && p.phase != "ready") continue;
        if (p.phase == "empty") continue;
        n += 1;
    }
    return n;
}

function living_count() {
    var n = 0;
    for (var i = 0; i < array_length(global.crew); i++) {
        if (global.crew[i].alive) n += 1;
    }
    return n;
}

function role_on(pad_i, role) {
    for (var i = 0; i < array_length(global.crew); i++) {
        var cr = global.crew[i];
        if (!cr.alive) continue;
        if (cr.pad == pad_i && cr.role == role) return true;
    }
    return false;
}

function crew_on_count(pad_i) {
    var n = 0;
    for (var i = 0; i < array_length(global.crew); i++) {
        if (global.crew[i].alive && global.crew[i].pad == pad_i) n += 1;
    }
    return n;
}
