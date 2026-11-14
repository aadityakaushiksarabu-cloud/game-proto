function draw_game() {
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    global.hits = [];
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_stars();
    if (global.mode == "title") draw_title();
    else if (global.mode == "end") draw_end();
    else draw_play();
    if (global.help) draw_help();
    ui_dispatch();
    draw_set_alpha(1);
}

function draw_stars() {
    for (var i = 0; i < array_length(global.stars); i++) {
        var s = global.stars[i];
        var tw = 0.35 + 0.65 * (0.5 + 0.5 * sin(current_time / 700 + s.p));
        draw_set_alpha(tw);
        draw_set_color(make_color_rgb(190, 210, 220));
        draw_rectangle(s.x, s.y, s.x + s.r, s.y + s.r, false);
    }
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(70, 130, 190));
    draw_circle(812, 64, 16, false);
    draw_set_color(COL_BG);
    draw_circle(820, 60, 14, false);
    draw_set_alpha(1);
}

function pad_box(i) {
    var p = global.pads[i];
    return {
        x: 28 + p.c * 210,
        y: 86 + p.r * 152,
        w: 200,
        h: 142
    };
}

function hull_for(p) {
    if (p.phase == "empty") return make_color_rgb(18, 24, 34);
    if (p.phase == "build") return make_color_rgb(32, 28, 22);
    switch (p.kind) {
        case "farm": return make_color_rgb(22, 46, 34);
        case "solar": return make_color_rgb(50, 40, 22);
        case "o2": return make_color_rgb(18, 40, 58);
        case "shelter": return make_color_rgb(52, 44, 22);
        case "rtg": return make_color_rgb(54, 30, 24);
        case "hab": return make_color_rgb(26, 40, 60);
        case "ice": return make_color_rgb(28, 44, 54);
        case "med": return make_color_rgb(46, 28, 36);
        case "comms": return make_color_rgb(24, 36, 52);
    }
    return COL_HULL;
}

function neighbor_built_gap(c, r) {
    if (c < 0 || r < 0 || c > 3 || r > 2) return false;
    return true;
}

function draw_gap_line(x1, y1, x2, y2, gap) {
    draw_set_alpha(1);
    if (!gap) {
        draw_line_width(x1, y1, x2, y2, 2);
        return;
    }
    if (abs(x2 - x1) >= abs(y2 - y1)) {
        var mid = (x1 + x2) * 0.5;
        draw_line_width(x1, y1, mid - 16, y1, 2);
        draw_line_width(mid + 16, y2, x2, y2, 2);
    } else {
        var midy = (y1 + y2) * 0.5;
        draw_line_width(x1, y1, x1, midy - 14, 2);
        draw_line_width(x2, midy + 14, x2, y2, 2);
    }
}

function draw_icon(kind, cx, cy) {
    draw_set_alpha(1);
    if (kind == "solar") {
        draw_set_color(COL_PWR);
        draw_line_width(cx - 18, cy + 8, cx + 18, cy - 8, 3);
        draw_line_width(cx - 18, cy + 16, cx + 18, cy, 3);
        draw_circle(cx + 22, cy - 16, 5, false);
    } else if (kind == "farm") {
        draw_set_color(COL_FOOD);
        for (var i = 0; i < 4; i++) draw_rectangle(cx - 16 + i * 10, cy - 8, cx - 12 + i * 10, cy + 12, false);
    } else if (kind == "o2") {
        draw_set_color(COL_O2);
        draw_circle(cx, cy, 12, true);
        draw_circle(cx, cy, 4, false);
    } else if (kind == "ice") {
        draw_set_color(COL_O2);
        draw_triangle(cx, cy - 14, cx - 12, cy + 10, cx + 12, cy + 10, false);
    } else if (kind == "shelter") {
        draw_set_color(COL_RAD);
        draw_rectangle(cx - 16, cy - 10, cx + 16, cy + 12, false);
        draw_set_color(COL_HULL);
        draw_rectangle(cx - 8, cy - 2, cx + 8, cy + 12, false);
    } else if (kind == "berm") {
        draw_set_color(make_color_rgb(150, 130, 90));
        draw_triangle(cx - 22, cy + 10, cx, cy - 12, cx + 22, cy + 10, false);
    } else if (kind == "rtg") {
        draw_set_color(COL_RED);
        draw_circle(cx, cy, 10, false);
        draw_set_color(COL_AMBER);
        draw_circle(cx, cy, 4, false);
    } else if (kind == "med") {
        draw_set_color(COL_RED);
        draw_rectangle(cx - 4, cy - 14, cx + 4, cy + 14, false);
        draw_rectangle(cx - 14, cy - 4, cx + 14, cy + 4, false);
    } else if (kind == "comms") {
        draw_set_color(COL_LINE);
        draw_line_width(cx, cy + 14, cx, cy - 12, 2);
        draw_circle(cx, cy - 8, 8, true);
        draw_circle(cx, cy - 8, 14, true);
    } else if (kind == "battery") {
        draw_set_color(COL_PWR);
        draw_rectangle(cx - 14, cy - 10, cx - 4, cy + 12, false);
        draw_rectangle(cx + 2, cy - 10, cx + 12, cy + 12, false);
    } else if (kind == "hab") {
        draw_set_color(COL_LINE);
        draw_rectangle(cx - 18, cy - 8, cx - 4, cy + 10, true);
        draw_rectangle(cx + 2, cy - 8, cx + 16, cy + 10, true);
    } else if (kind == "airlock") {
        draw_set_color(COL_AMBER);
        draw_circle(cx, cy, 12, true);
        draw_line(cx - 12, cy, cx + 12, cy);
    }
}

function draw_base(clickable) {
    draw_set_alpha(1);
    draw_set_color(COL_DECK2);
    draw_rectangle(16, 74, 868, 548, false);
    draw_set_color(COL_DECK);
    for (var c = 0; c < array_length(global.craters); c++) {
        var cr = global.craters[c];
        draw_set_alpha(0.35);
        draw_set_color(make_color_rgb(22, 20, 18));
        draw_circle(cr.x, cr.y, cr.r, false);
    }
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(90, 78, 64));
    draw_rectangle(16, 74, 868, 548, true);

    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        var b = pad_box(i);
        draw_set_color(hull_for(p));
        draw_rectangle(b.x, b.y, b.x + b.w, b.y + b.h, false);
        draw_set_alpha(0.35);
        draw_set_color(COL_HULL2);
        for (var yy = b.y + 22; yy < b.y + b.h - 6; yy += 7) {
            draw_line(b.x + 6, yy, b.x + b.w - 6, yy);
        }
        draw_set_alpha(1);
        var edge = COL_DIML;
        if (p.phase == "ready") edge = COL_LINE;
        if (p.phase == "build") edge = COL_AMBER;
        if (global.mode == "play" && global.sel == i) edge = COL_AMBER;
        if (global.alert && p.kind == "solar") edge = COL_RED;
        draw_set_color(edge);
        var gap_l = neighbor_built_gap(p.c - 1, p.r);
        var gap_r = neighbor_built_gap(p.c + 1, p.r);
        var gap_u = neighbor_built_gap(p.c, p.r - 1);
        var gap_d = neighbor_built_gap(p.c, p.r + 1);
        draw_gap_line(b.x, b.y, b.x, b.y + b.h, gap_l);
        draw_gap_line(b.x + b.w, b.y, b.x + b.w, b.y + b.h, gap_r);
        draw_gap_line(b.x, b.y, b.x + b.w, b.y, gap_u);
        draw_gap_line(b.x, b.y + b.h, b.x + b.w, b.y + b.h, gap_d);

        var info = kind_info(p.kind);
        var label = (p.phase == "empty") ? "BAY" : info.label;
        draw_set_color(p.phase == "empty" ? COL_DIM : COL_TEXT);
        draw_text(b.x + 10, b.y + 6, label);
        draw_icon(p.phase == "empty" ? "" : p.kind, b.x + b.w * 0.5, b.y + 62);

        var state = "";
        var sc = COL_DIM;
        if (p.phase == "build") {
            state = "WORK " + string(floor(p.prog)) + "/" + string(p.need);
            sc = COL_AMBER;
        } else if (p.phase == "ready" && load_cost(p.kind) > 0) {
            if (!p.want) { state = "OFF"; sc = COL_DIM; }
            else if (p.on) { state = "POWER"; sc = COL_GREEN; }
            else { state = "BROWN"; sc = COL_RED; }
        } else if (p.kind == "solar" && p.phase == "ready") {
            state = "SUN " + string(round(sun_factor(global.day) * global.dust * 100)) + "%";
            sc = COL_PWR;
        } else if (p.kind == "rtg" && p.phase == "ready") {
            state = "STEADY";
            sc = COL_PWR;
        } else if (p.kind == "farm" && p.phase == "ready") {
            var ramp = clamp((global.day - p.ready_day) / 4, 0, 1);
            state = "GROW " + string(round(ramp * 100)) + "%";
            sc = COL_FOOD;
        }
        draw_set_color(sc);
        draw_text(b.x + 10, b.y + 24, state);

        var slot = 0;
        for (var ci = 0; ci < array_length(global.crew); ci++) {
            var cr = global.crew[ci];
            if (!cr.alive || cr.pad != i) continue;
            var cx = b.x + 16 + slot * 22;
            var cy = b.y + b.h - 22 + sin(current_time / 280 + ci) * 2;
            draw_set_color(cr.col);
            draw_circle(cx, cy, 7, false);
            draw_set_color(COL_BG);
            draw_rectangle(cx - 4, cy - 2, cx + 4, cy, false);
            slot += 1;
        }

        if (clickable) ui_hit(b.x, b.y, b.w, b.h, "pad", i, 0);
    }
}

function draw_bar(x, y, w, portion, col, label) {
    portion = clamp(portion, 0, 1);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(x, y, x + w, y + 10, false);
    draw_set_color(col);
    draw_rectangle(x, y, x + w * portion, y + 10, false);
    draw_set_color(COL_DIML);
    draw_rectangle(x, y, x + w, y + 10, true);
    draw_set_color(COL_TEXT);
    draw_text(x, y + 12, label);
}

function draw_play() {
    draw_set_color(COL_TEXT);
    draw_text(24, 16, "LUNAR HOLD");
    draw_set_color(COL_AMBER);
    draw_text(150, 16, "DAY " + string(global.day));
    draw_set_color(COL_LINE);
    draw_text(240, 16, day_to_ymd(global.day));
    var nleft = days_until_night(global.day);
    draw_set_color(nleft == 0 ? COL_RED : COL_PWR);
    draw_text(380, 16, nleft == 0 ? "LUNAR NIGHT" : ("NIGHT IN " + string(nleft)));
    var clock = 0;
    if (global.day_len > 0) clock = clamp(global.acc / global.day_len, 0, 1);
    draw_set_color(make_color_rgb(8, 12, 18));
    draw_rectangle(24, 42, 520, 52, false);
    draw_set_color(global.paused ? COL_AMBER : COL_LINE);
    draw_rectangle(24, 42, 24 + 496 * clock, 52, false);
    draw_set_color(COL_DIML);
    draw_rectangle(24, 42, 520, 52, true);

    var px = 540;
    ui_button(px, 14, 36, 28, global.spd == 1 ? "[1]" : "1", true, "speed", 1, 0);
    ui_button(px + 42, 14, 36, 28, global.spd == 3 ? "[3]" : "3", true, "speed", 3, 0);
    ui_button(px + 84, 14, 36, 28, global.spd == 8 ? "[8]" : "8", true, "speed", 8, 0);
    ui_button(px + 126, 14, 88, 28, global.paused ? "RUN" : "HOLD", true, "pause", 0, 0);
    if (global.paused) {
        draw_set_color(COL_AMBER);
        draw_text(px + 222, 18, "PAUSED");
    }

    draw_base(true);
    draw_log();
    draw_side();

    if (global.alert) {
        var a = 0.18 + 0.12 * (0.5 + 0.5 * sin(current_time / 180));
        draw_set_alpha(a);
        draw_set_color(COL_RED);
        draw_rectangle(12, 8, 876, 700, true);
        draw_rectangle(14, 10, 874, 698, true);
        draw_set_alpha(1);
    }
}

function draw_log() {
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(8, 12, 20));
    draw_rectangle(16, 556, 868, 704, false);
    draw_set_color(COL_DIML);
    draw_rectangle(16, 556, 868, 704, true);
    draw_set_color(COL_LINE);
    draw_text(28, 562, "LOG");
    for (var i = 0; i < array_length(global.log); i++) {
        draw_set_color(i == array_length(global.log) - 1 ? COL_TEXT : COL_DIM);
        draw_text(28, 584 + i * 16, global.log[i]);
    }
}

function draw_side() {
    draw_set_alpha(1);
    draw_set_color(COL_PANEL);
    draw_rectangle(884, 12, 1268, 704, false);
    draw_set_color(COL_LINE);
    draw_rectangle(884, 12, 1268, 704, true);
    draw_text(900, 20, "STATION");

    var proj = simulate_economy(false);
    draw_bar(900, 48, 340, global.o2 / 80, COL_O2, "OXYGEN  " + num1(global.o2) + " KG   " + signed(proj.o2_end_raw - global.o2));
    draw_bar(900, 84, 340, global.food / 80, COL_FOOD, "FOOD  " + num1(global.food) + "   " + signed(proj.food_end_raw - global.food));
    draw_bar(900, 120, 340, global.water / 160, COL_O2, "WATER  " + num1(global.water) + " KG   " + signed(proj.water - global.water));
    var dose_now = GCR_MSV + global.today.prompt + global.today.proton;
    draw_bar(900, 156, 340, clamp(dose_now / 30, 0, 1), dose_now > 8 ? COL_RED : COL_RAD, "RADIATION  " + num1(dose_now) + " mSv TODAY");
    var cap = max(1, pad_count("battery", true) * BATT_KWH);
    draw_bar(900, 192, 340, global.battery / cap, COL_PWR, "POWER  " + string(floor(proj.gen)) + " IN  " + string(floor(proj.used)) + " USED");
    draw_bar(900, 228, 340, global.cargo / START_CARGO, COL_AMBER, "CARGO  " + string(floor(global.cargo)));

    draw_set_color(COL_DIML);
    draw_rectangle(900, 268, 1252, 360, true);
    draw_set_color(COL_LINE);
    draw_text(908, 274, forecast_visible() ? "DONKI LOCK" : "DONKI DARK");
    if (!forecast_visible()) {
        draw_set_color(COL_DIM);
        draw_text(908, 296, "COMMS IS DOWN.");
        draw_text(908, 314, "STORMS WILL NOT CALL AHEAD.");
    } else if (!global.today.significant) {
        draw_set_color(COL_GREEN);
        draw_text(908, 296, day_to_ymd(global.day) + "  QUIET");
        draw_set_color(COL_DIM);
        draw_text(908, 316, "GCR " + num1(GCR_MSV) + " mSv  CARRY " + num1(global.proton_carry));
    } else {
        draw_set_color(COL_RED);
        draw_text(908, 294, global.today.headline);
        draw_set_color(COL_TEXT);
        var extra = "";
        if (array_length(global.today.lines) > 1) extra = global.today.lines[1];
        draw_text_ext(908, 314, extra, 16, 330);
    }

    var window_open = (global.day mod 5) == 0;
    if (window_open) ui_button(900, 370, 352, 32, "ASCEND TO ORBIT", true, "ascend", 0, 0);
    else ui_button(900, 370, 352, 32, "WINDOW IN " + string(5 - (global.day mod 5)) + " DAYS", false, "ascend", 0, 0);

    draw_set_color(COL_DIM);
    draw_text(900, 408, "CREW  CLICK, THEN A ROOM");
    for (var i = 0; i < array_length(global.crew); i++) {
        var cr = global.crew[i];
        var px = 900 + i * 118;
        var py = 428;
        draw_set_color(make_color_rgb(8, 12, 18));
        draw_rectangle(px, py, px + 110, py + 62, false);
        var edge = COL_DIML;
        if (global.crew_sel == i) edge = COL_AMBER;
        if (!cr.alive) edge = COL_RED;
        draw_set_color(edge);
        draw_rectangle(px, py, px + 110, py + 62, true);
        draw_set_color(cr.alive ? cr.col : COL_DIM);
        draw_circle(px + 16, py + 20, 8, false);
        draw_set_color(COL_TEXT);
        draw_text(px + 30, py + 8, cr.short);
        draw_set_color(COL_DIM);
        draw_text(px + 30, py + 26, cr.alive ? cr.name : "LOST");
        var pending = dose_now * shield_for(cr.pad);
        draw_set_color(pending > 8 ? COL_RED : COL_RAD);
        draw_text(px + 8, py + 42, cr.alive ? (string(floor(cr.hp)) + " HP  " + num1(pending)) : "--");
        if (cr.alive) ui_hit(px, py, 110, 62, "crew", i, 0);
    }

    draw_selected();
}

function signed(n) {
    if (n > 0.05) return "+" + num1(n);
    if (n < -0.05) return num1(n);
    return "0";
}

function draw_selected() {
    if (global.sel < 0 || global.sel >= array_length(global.pads)) return;
    var p = global.pads[global.sel];
    var info = kind_info(p.kind);
    draw_set_color(COL_LINE);
    draw_text(900, 500, p.phase == "empty" ? "OPEN BAY" : info.name);
    draw_set_color(COL_DIM);
    var desc = p.phase == "empty" ? "PICK A MODULE. CARGO IS THE BUILD LIMIT." : info.desc;
    draw_text_ext(900, 518, desc, 16, 340);

    if (p.phase == "ready" && load_cost(p.kind) > 0) {
        ui_button(900, 556, 170, 28, p.want ? "POWER OFF" : "POWER ON", true, "power", global.sel, 0);
    }
    if (global.crew_sel >= 0) ui_button(1080, 556, 172, 28, "SEND TO HAB", true, "recall", 0, 0);

    if (p.phase == "empty") {
        for (var k = 0; k < array_length(global.kind_order); k++) {
            var key = global.kind_order[k];
            var inf = kind_info(key);
            var have = pad_count(key, false);
            var ok = (have < inf.max) && (global.cargo >= inf.cost);
            var label = inf.label + " " + string(inf.cost);
            if (have >= inf.max) label = "MAX";
            var bx = 900 + (k mod 3) * 118;
            var by = 586 + floor(k / 3) * 28;
            ui_button(bx, by, 112, 26, label, ok, "build", global.sel, key);
        }
    }
}

function draw_title() {
    draw_set_alpha(0.55);
    draw_base(false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(860, 40, 1240, 680, false);
    draw_set_color(COL_LINE);
    draw_rectangle(860, 40, 1240, 680, true);
    draw_set_color(COL_LINE);
    draw_text(888, 70, "EXPEDITION");
    draw_set_color(COL_TEXT);
    draw_text_transformed(888, 100, "LUNAR HOLD", 2, 2, 0);
    draw_set_color(COL_DIM);
    draw_text_ext(888, 170, "THREE CREW. FOOD, OXYGEN, RADIATION. THE FLARE TAPE IS NASA DONKI. EVERY FIFTH DAY YOU MAY CLIMB TO ORBIT AND FILE THE SCORE.", 18, 320);
    ui_button(888, 280, 312, 40, "BEGIN EXPEDITION", true, "begin", 0, 0);
    ui_button(888, 332, 312, 36, "HOW TO HOLD", true, "help", 0, 0);
    draw_set_color(COL_AMBER);
    draw_text(888, 400, "BEST SCORE  " + string(floor(global.best)));
    draw_set_color(COL_LINE);
    draw_text_ext(888, 430, global.donki_status, 18, 320);
    draw_set_color(COL_DIM);
    draw_text_ext(888, 490, "CATALOG EPOCH " + global.epoch + ". LIVE CHECK USES CCMC DONKI-API. O2 IS 0.84 KG PER CREW-DAY.", 18, 320);
    draw_text(888, 580, "ENTER TO BEGIN");
    draw_text(888, 602, "SPACE PAUSE    1 3 8 SPEED");
    draw_text(888, 624, "H HELP    A ASCEND");
}

function draw_end() {
    draw_set_alpha(0.4);
    draw_base(false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(340, 70, 940, 640, false);
    draw_set_color(global.won ? COL_LINE : COL_RED);
    draw_rectangle(340, 70, 940, 640, true);
    draw_set_color(global.won ? COL_AMBER : COL_RED);
    draw_text(372, 96, global.won ? "ORBIT" : "LOST");
    draw_set_color(COL_TEXT);
    draw_text_transformed(372, 124, global.won ? "SCORE FILED" : "HOLD FAILED", 2, 2, 0);
    draw_set_color(COL_LINE);
    draw_text(372, 190, "DAY " + string(global.day) + "    " + day_to_ymd(global.day));
    draw_set_color(COL_TEXT);
    for (var i = 0; i < array_length(global.report); i++) {
        draw_text(372, 230 + i * 22, global.report[i]);
    }
    draw_set_color(COL_AMBER);
    draw_text_transformed(372, 430, string(global.points), 2, 2, 0);
    draw_set_color(COL_DIM);
    draw_text(372, 490, "BEST  " + string(floor(global.best)));
    ui_button(372, 540, 240, 36, "NEW EXPEDITION", true, "again", 0, 0);
    ui_button(628, 540, 240, 36, "TITLE", true, "title", 0, 0);
}

function draw_help() {
    draw_set_alpha(0.72);
    draw_set_color(COL_BG);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(8, 14, 24));
    draw_rectangle(260, 40, 1020, 680, false);
    draw_set_color(COL_LINE);
    draw_rectangle(260, 40, 1020, 680, true);
    draw_text(288, 58, "HOW TO HOLD THE MOON");
    draw_set_color(COL_TEXT);
    var body = "YOU MANAGE FOOD, OXYGEN, AND RADIATION FOR THREE CREW.\n\nBUILD SOLAR POWER, AN ICE EXTRACTOR, AN OXYGENATOR, A CALORIE FARM, AND KILOPOWER BEFORE THE FOURTEEN-DAY NIGHT.\n\nA REGOLITH BERM CUTS THE DAILY DOSE. THE STORM SHELTER IS FOR DONKI ALERTS. COMMS TELLS YOU THE FLARE IS COMING. WITHOUT IT, YOU ONLY SEE THE DOSE AFTER IT LANDS.\n\nCLICK A CREW PORTRAIT, THEN A ROOM. THE COMMANDER BUILDS FASTER. THE ENGINEER CLEANS ARRAYS AND RUNS THE PLANT. THE SCIENTIST GROWS MORE FOOD.\n\nEVERY 5TH DAY THE LANDER CAN REACH ORION. THAT IS WHEN THE SCORE IS FILED. STAY LONGER AND THE NEXT FLARE IS YOURS.\n\nSPACE PAUSES. 1, 3, AND 8 SET THE CLOCK. H CLOSES THIS PAGE.\n\nNASA NUMBERS IN THE MODEL: 0.84 KG OXYGEN PER PERSON-DAY, ELECTROLYSIS AT 0.85 KG OXYGEN PER KG OF WATER, AND A LUNAR GCR NEAR 0.38 mSv PER DAY. STORM DAYS COME FROM THE DONKI FLARE, CME, AND SEP FEEDS.";
    draw_text_ext(288, 96, body, 18, 700);
    ui_button(288, 620, 200, 34, "CLOSE", true, "closehelp", 0, 0);
}
