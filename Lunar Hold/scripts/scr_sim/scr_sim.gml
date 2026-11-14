function sun_factor(day) {
    var age = (day + 2) mod 28;
    if (age < 0) age += 28;
    if (age >= 14) return 0;
    return sin((age / 14) * pi);
}

function days_until_night(day) {
    var age = (day + 2) mod 28;
    if (age < 0) age += 28;
    if (age >= 14) return 0;
    return 14 - age;
}

function in_night(day) {
    return sun_factor(day) <= 0;
}

function shield_for(pad_i) {
    var berm = pad_count("berm", true) > 0;
    var p = global.pads[pad_i];
    if (p.kind == "shelter" && p.phase == "ready") return 0.08;
    if (p.phase != "ready") return berm ? 0.82 : 1;
    if (p.kind == "solar") return 1;
    if (p.kind == "berm") return 0.62;
    if (berm) return 0.32;
    return 0.70;
}

function load_cost(kind) {
    switch (kind) {
        case "hab": return HAB_KWH;
        case "farm": return FARM_KWH;
        case "o2": return O2_KWH;
        case "ice": return ICE_KWH;
        case "med": return MED_KWH;
        case "comms": return COMMS_KWH;
        case "shelter": return SHELTER_KWH;
    }
    return 0;
}

function load_priority(kind) {
    switch (kind) {
        case "med": return 1;
        case "farm": return 2;
        case "ice": return 3;
        case "comms": return 4;
        case "o2": return 5;
        case "shelter": return 6;
        case "hab": return 7;
    }
    return 0;
}

function simulate_economy(apply) {
    var sun = sun_factor(global.day);
    var dust = global.dust;
    if (dust < 0.35) dust = 0.35;
    var clean = 0;
    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        if (p.kind == "solar" && p.phase == "ready" && role_on(i, "engineer")) clean += 0.16;
        else if (p.kind == "solar" && p.phase == "ready" && crew_on_count(i) > 0) clean += 0.08;
    }
    dust = clamp(dust - 0.01 + clean, 0.35, 1);

    var solar_n = pad_count("solar", true);
    var rtg_n = pad_count("rtg", true);
    var batt_n = pad_count("battery", true);
    var gen = solar_n * SOLAR_KWH * sun * dust + rtg_n * RTG_KWH;
    var cap = batt_n * BATT_KWH;
    var store = global.battery;

    var loads = [];
    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        if (p.phase != "ready") continue;
        var cost = load_cost(p.kind);
        if (cost <= 0) continue;
        if (p.kind == "shelter" && crew_on_count(i) <= 0) cost = 0;
        if (cost <= 0) continue;
        array_push(loads, { i: i, kind: p.kind, cost: cost, pri: load_priority(p.kind), want: p.want });
    }
    for (var a = 0; a < array_length(loads); a++) {
        for (var b = a + 1; b < array_length(loads); b++) {
            if (loads[b].pri > loads[a].pri) {
                var tmp = loads[a];
                loads[a] = loads[b];
                loads[b] = tmp;
            }
        }
    }

    var energy = gen;
    var used = 0;
    var onmap = {};
    for (var n = 0; n < array_length(loads); n++) {
        var item = loads[n];
        var running = false;
        if (item.want) {
            if (energy >= item.cost) {
                energy -= item.cost;
                running = true;
            } else if (store >= item.cost) {
                store -= item.cost;
                running = true;
            }
        }
        if (running) used += item.cost;
        onmap[$ string(item.i)] = running;
    }
    store = min(cap, store + energy * 0.85);

    var hab_on = false;
    var comms_on = false;
    var o2_units = 0;
    var ice_add = 0;
    var food_made = 0;
    var o2_made = 0;
    var water = global.water;

    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        var running = false;
        if (variable_struct_exists(onmap, string(i))) running = onmap[$ string(i)];
        if (p.kind == "hab" && p.phase == "ready") hab_on = running;
        if (p.kind == "comms" && running) comms_on = true;
        if (p.kind == "ice" && running) {
            var bonus = role_on(i, "engineer") ? 1.15 : 1;
            ice_add += ICE_KG * bonus;
        }
        if (p.kind == "o2" && running) {
            var bonus = role_on(i, "engineer") ? 1.15 : 1;
            o2_units += bonus;
        }
    }
    water += ice_add;

    var alive = living_count();
    var drink = CREW_WATER * alive;
    var drink_use = min(water, drink);
    water -= drink_use;

    var o2_need = O2_WATER * o2_units;
    var o2_water = min(water, o2_need);
    water -= o2_water;
    if (o2_need > 0) o2_made += O2_YIELD * o2_units * (o2_water / o2_need);

    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        var running = false;
        if (variable_struct_exists(onmap, string(i))) running = onmap[$ string(i)];
        if (p.kind != "farm" || !running) continue;
        var ramp = clamp((global.day - p.ready_day) / 4, 0, 1);
        var bonus = role_on(i, "scientist") ? 1.25 : 1;
        if (water >= FARM_WATER) {
            water -= FARM_WATER;
            food_made += FARM_FOOD * ramp * bonus;
            o2_made += FARM_O2 * ramp;
        } else if (water > 0 && FARM_WATER > 0) {
            var portion = water / FARM_WATER;
            water = 0;
            food_made += FARM_FOOD * ramp * bonus * portion;
            o2_made += FARM_O2 * ramp * portion;
        }
    }

    var o2_use = CREW_O2 * alive;
    if (!hab_on) o2_use += 1.6;
    var food_use = CREW_FOOD * alive;
    var o2_end = global.o2 + o2_made - o2_use;
    var food_end = global.food + food_made - food_use;

    var result = {
        o2: max(0, o2_end),
        food: max(0, food_end),
        water: max(0, water),
        gen: gen,
        used: used,
        sun: sun,
        dust: dust,
        hab_on: hab_on,
        comms_on: comms_on,
        o2_made: o2_made,
        food_made: food_made,
        o2_end_raw: o2_end,
        food_end_raw: food_end,
        store: store
    };

    if (!apply) return result;

    global.dust = dust;
    global.battery = store;
    global.o2 = result.o2;
    global.food = result.food;
    global.water = result.water;
    global.comms_up = comms_on;
    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        if (p.phase != "ready") {
            p.on = false;
            continue;
        }
        if (p.kind == "solar" || p.kind == "rtg" || p.kind == "airlock" || p.kind == "berm" || p.kind == "battery") {
            p.on = true;
            continue;
        }
        if (variable_struct_exists(onmap, string(i))) p.on = onmap[$ string(i)];
        else p.on = false;
    }
    return result;
}

function apply_construction() {
    for (var i = 0; i < array_length(global.pads); i++) {
        var p = global.pads[i];
        if (p.phase != "build") continue;
        var gain = 0;
        for (var c = 0; c < array_length(global.crew); c++) {
            var cr = global.crew[c];
            if (!cr.alive || cr.pad != i) continue;
            gain += (cr.role == "commander") ? 2 : 1;
        }
        p.prog += gain;
        if (p.prog >= p.need) {
            p.phase = "ready";
            p.ready_day = global.day;
            p.prog = p.need;
            p.on = false;
            log_line(kind_info(p.kind).name + " ONLINE.");
        }
    }
}

function apply_radiation(hab_on) {
    var raw = GCR_MSV + global.today.prompt + global.today.proton;
    for (var i = 0; i < array_length(global.crew); i++) {
        var cr = global.crew[i];
        if (!cr.alive) continue;
        var dose = raw * shield_for(cr.pad);
        cr.dose += dose;
        if (dose > 6) cr.hp -= (dose - 6) * 2;
        if (global.o2 <= 0) cr.hp -= 28;
        if (global.food <= 0) cr.hp -= 14;
        if (!hab_on && !(global.pads[cr.pad].kind == "shelter" && global.pads[cr.pad].phase == "ready")) cr.hp -= 10;
        var quiet = (global.o2 > 0 && global.food > 0 && dose < 3);
        if (quiet) {
            var pad = global.pads[cr.pad];
            if (pad.kind == "med" && pad.on) cr.hp += 16;
            else if (pad.kind == "hab") cr.hp += 6;
        }
        if (cr.hp > 100) cr.hp = 100;
        if (cr.hp <= 0) {
            cr.hp = 0;
            cr.alive = false;
            log_line(cr.name + " IS DEAD.");
        }
    }
    global.proton_carry = global.today.fresh * 0.5;
}

function apply_hazards(sun) {
    if (sun > 0.25 && random(1) < 0.08) {
        global.dust = max(0.35, global.dust - 0.14);
        log_line("LEVITATED DUST. ARRAYS DIM.");
    }
    if (random(1) < 0.045) {
        if (pad_count("berm", true) > 0) log_line("BERM CAUGHT A MICROMETEOROID.");
        else {
            global.o2 = max(0, global.o2 - 2);
            log_line("MICROMETEOROID. OXYGEN BLEEDS.");
        }
    }
}

function resolve_day() {
    apply_construction();
    var econ = simulate_economy(true);
    apply_radiation(econ.hab_on);
    apply_hazards(econ.sun);
    if (living_count() <= 0) {
        finish_run(false);
        return;
    }
    global.day += 1;
    announce_day();
}

function tally_score(won) {
    var alive = living_count();
    var dose = 0;
    var dead = 0;
    for (var i = 0; i < array_length(global.crew); i++) {
        dose += global.crew[i].dose;
        if (!global.crew[i].alive) dead += 1;
    }
    var built = 0;
    for (var i = 0; i < array_length(global.pads); i++) {
        if (global.pads[i].phase == "ready" && global.pads[i].kind != "hab" && global.pads[i].kind != "airlock") built += 1;
    }
    var days = global.day * 100;
    var crew_pts = alive * 800;
    var build_pts = built * 60;
    var log_pts = global.logged * 40;
    var stock = floor(global.food) * 6 + floor(global.o2) * 2 + floor(global.water);
    var dose_bonus = 0;
    if (alive > 0 && (dose / alive) < 180) dose_bonus = 320;
    var total = days + crew_pts + build_pts + log_pts + stock + dose_bonus;
    if (!won) total = floor(total * 0.4);
    global.report = [
        "DAYS ON THE SURFACE  " + string(days),
        "CREW STILL ALIVE  " + string(crew_pts),
        "MODULES  " + string(build_pts),
        "DONKI REPORTS FILED  " + string(log_pts),
        "STORES  " + string(stock),
        "LOW DOSE  " + string(dose_bonus)
    ];
    if (!won) array_push(global.report, "LOSS FILED AT 40 PERCENT");
    if (dead > 0) array_push(global.report, string(dead) + " CREW DID NOT COME HOME");
    return total;
}

function finish_run(won) {
    global.won = won;
    global.mode = "end";
    global.paused = true;
    global.help = false;
    global.points = tally_score(won);
    save_best(global.points);
    if (won) log_line("ORION HAS THE CREW. SCORE FILED.");
    else log_line("THE HOLD IS LOST. SCORE FILED.");
}

function try_ascend() {
    if (global.mode != "play") return;
    if ((global.day mod 5) != 0) {
        log_line("NO WINDOW. ORION RETURNS EVERY 5 DAYS.");
        return;
    }
    finish_run(true);
}

function start_run() {
    reset_run();
    global.mode = "play";
    global.help = false;
    global.acc = 0;
    announce_day();
}

function begin_build(pad_i, kind) {
    var info = kind_info(kind);
    var p = global.pads[pad_i];
    if (p.phase != "empty") return;
    if (pad_count(kind, false) >= info.max) return;
    if (global.cargo < info.cost) return;
    global.cargo -= info.cost;
    p.kind = kind;
    p.phase = "build";
    p.prog = 0;
    p.need = info.work;
    p.want = true;
    p.on = false;
    log_line("BUILD STARTED. " + info.name + ".");
}

function assign_crew(ci, pad_i) {
    var cr = global.crew[ci];
    if (!cr.alive) return;
    var p = global.pads[pad_i];
    if (p.phase == "empty") return;
    var cap = 1;
    if (p.kind == "hab" || p.kind == "shelter") cap = 3;
    var occupant = -1;
    var n = 0;
    for (var i = 0; i < array_length(global.crew); i++) {
        if (i == ci || !global.crew[i].alive) continue;
        if (global.crew[i].pad == pad_i) {
            n += 1;
            occupant = i;
        }
    }
    if (n >= cap && occupant >= 0) {
        global.crew[occupant].pad = 4;
        log_line(global.crew[occupant].name + " BACK TO THE HAB.");
    }
    cr.pad = pad_i;
    log_line(cr.name + " TO " + kind_info(p.kind).label + ".");
}

function toggle_power(pad_i) {
    var p = global.pads[pad_i];
    if (p.phase != "ready") return;
    if (load_cost(p.kind) <= 0) return;
    p.want = !p.want;
    log_line(kind_info(p.kind).label + (p.want ? " SET ON." : " SET OFF."));
}

function input_keys() {
    if (keyboard_check_pressed(ord("H"))) {
        global.help = !global.help;
        if (global.help && global.mode == "play") global.paused = true;
    }
    if (global.mode == "title") {
        if (keyboard_check_pressed(vk_enter)) start_run();
        return;
    }
    if (global.mode == "end") {
        if (keyboard_check_pressed(vk_enter)) start_run();
        if (keyboard_check_pressed(vk_escape)) global.mode = "title";
        return;
    }
    if (global.help) {
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_space)) global.help = false;
        return;
    }
    if (keyboard_check_pressed(vk_space) || keyboard_check_pressed(vk_escape)) global.paused = !global.paused;
    if (keyboard_check_pressed(ord("1"))) { global.spd = 1; }
    if (keyboard_check_pressed(ord("2"))) { global.spd = 3; }
    if (keyboard_check_pressed(ord("3"))) { global.spd = 8; }
    if (keyboard_check_pressed(ord("A"))) try_ascend();
}

function sim_step() {
    input_keys();
    if (global.mode != "play" || global.help || global.paused) return;
    var dt = delta_time * 0.000001;
    if (dt > 0.08) dt = 0.08;
    global.acc += dt * global.spd;
    var guard = 0;
    while (global.acc >= global.day_len && guard < 2) {
        global.acc -= global.day_len;
        resolve_day();
        guard += 1;
        if (global.paused || global.mode != "play") break;
    }
}
