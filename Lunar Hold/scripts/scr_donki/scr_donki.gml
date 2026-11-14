function ymd_to_jd(y, m, d) {
    var a = floor((14 - m) / 12);
    var yy = y + 4800 - a;
    var mm = m + 12 * a - 3;
    return d + floor((153 * mm + 2) / 5) + 365 * yy + floor(yy / 4) - floor(yy / 100) + floor(yy / 400) - 32045;
}

function jd_to_ymd(jd) {
    var a = jd + 32044;
    var b = floor((4 * a + 3) / 146097);
    var c = a - floor((146097 * b) / 4);
    var d = floor((4 * c + 3) / 1461);
    var e = c - floor((1461 * d) / 4);
    var m = floor((5 * e + 2) / 153);
    var day = e - floor((153 * m + 2) / 5) + 1;
    var month = m + 3 - 12 * floor(m / 10);
    var year = 100 * b + d - 4800 + floor(m / 10);
    return { y: year, m: month, d: day };
}

function ymd_pack(y, m, d) {
    var ms = string(m);
    var ds = string(d);
    if (m < 10) ms = "0" + ms;
    if (d < 10) ds = "0" + ds;
    return string(y) + "-" + ms + "-" + ds;
}

function parse_ymd(s) {
    if (is_undefined(s) || string_length(s) < 10) return undefined;
    return {
        y: real(string_copy(s, 1, 4)),
        m: real(string_copy(s, 6, 2)),
        d: real(string_copy(s, 9, 2))
    };
}

function day_to_ymd(day) {
    var ep = parse_ymd(global.epoch);
    var jd = ymd_to_jd(ep.y, ep.m, ep.d) + day - 1;
    var p = jd_to_ymd(jd);
    return ymd_pack(p.y, p.m, p.d);
}

function today_clock_string() {
    return ymd_pack(current_year, current_month, current_day);
}

function struct_str(s, key, fallback) {
    if (!is_struct(s)) return fallback;
    if (!variable_struct_exists(s, key)) return fallback;
    var v = s[$ key];
    if (is_undefined(v) || is_struct(v) || is_array(v)) return fallback;
    return string(v);
}

function donki_bucket(ymd) {
    if (!variable_struct_exists(global.donki_dates, ymd)) {
        global.donki_dates[$ ymd] = { flares: [], cmes: [], seps: [] };
    }
    return global.donki_dates[$ ymd];
}

function donki_add_flare(t, cls, ar, loc, alert, note) {
    if (string_length(t) < 10 || string_length(cls) < 1) return false;
    var key = "F|" + t + "|" + cls;
    if (variable_struct_exists(global.donki_seen, key)) return false;
    global.donki_seen[$ key] = true;
    var ymd = string_copy(t, 1, 10);
    array_push(donki_bucket(ymd).flares, {
        t: t, class: cls, ar: ar, loc: loc, alert: alert, note: note
    });
    global.donki_flare_n += 1;
    return true;
}

function donki_add_cme(t, kms, earth, note) {
    if (string_length(t) < 10) return false;
    var key = "C|" + t + "|" + string(floor(kms));
    if (variable_struct_exists(global.donki_seen, key)) return false;
    global.donki_seen[$ key] = true;
    var ymd = string_copy(t, 1, 10);
    array_push(donki_bucket(ymd).cmes, { t: t, speed: kms, earth: earth, note: note });
    global.donki_cme_n += 1;
    return true;
}

function donki_add_sep(t, note) {
    if (string_length(t) < 10) return false;
    var key = "S|" + t;
    if (variable_struct_exists(global.donki_seen, key)) return false;
    global.donki_seen[$ key] = true;
    var ymd = string_copy(t, 1, 10);
    array_push(donki_bucket(ymd).seps, { t: t, note: note });
    global.donki_sep_n += 1;
    return true;
}

function donki_note_clean(s) {
    if (is_undefined(s)) return "";
    var t = string_replace_all(string(s), "\n", " ");
    t = string_replace_all(t, "\r", " ");
    if (string_length(t) > 140) t = string_copy(t, 1, 140);
    return t;
}

function donki_ingest_flares(arr) {
    if (!is_array(arr)) return 0;
    var n = 0;
    for (var i = 0; i < array_length(arr); i++) {
        var f = arr[i];
        if (!is_struct(f)) continue;
        var t = struct_str(f, "beginTime", struct_str(f, "t", ""));
        var cls = struct_str(f, "classType", struct_str(f, "class", ""));
        var ar = 0;
        if (variable_struct_exists(f, "activeRegionNum") && !is_undefined(f[$ "activeRegionNum"])) ar = real(f[$ "activeRegionNum"]);
        else if (variable_struct_exists(f, "ar") && !is_undefined(f[$ "ar"])) ar = real(f[$ "ar"]);
        var loc = struct_str(f, "sourceLocation", struct_str(f, "loc", ""));
        var note = donki_note_clean(struct_str(f, "note", ""));
        var alert = false;
        if (variable_struct_exists(f, "alert") && f[$ "alert"] == true) alert = true;
        if (variable_struct_exists(f, "sentNotifications") && is_array(f[$ "sentNotifications"]) && array_length(f[$ "sentNotifications"]) > 0) alert = true;
        if (donki_add_flare(t, cls, ar, loc, alert, note)) n += 1;
    }
    return n;
}

function donki_text_has(s, word) {
    return string_pos(word, string_upper(s)) > 0;
}

function donki_ingest_cmes(arr) {
    if (!is_array(arr)) return 0;
    var n = 0;
    for (var i = 0; i < array_length(arr); i++) {
        var c = arr[i];
        if (!is_struct(c)) continue;
        if (variable_struct_exists(c, "speed") && variable_struct_exists(c, "t")) {
            var earth = false;
            if (variable_struct_exists(c, "earth")) earth = c[$ "earth"] == true;
            if (donki_add_cme(struct_str(c, "t", ""), real(c[$ "speed"]), earth, donki_note_clean(struct_str(c, "note", "")))) n += 1;
            continue;
        }
        var start = struct_str(c, "startTime", "");
        var analyses = undefined;
        if (variable_struct_exists(c, "cmeAnalyses")) analyses = c[$ "cmeAnalyses"];
        if (!is_array(analyses) || array_length(analyses) < 1) continue;
        var a = analyses[0];
        for (var k = 0; k < array_length(analyses); k++) {
            var cand = analyses[k];
            if (is_struct(cand) && variable_struct_exists(cand, "isMostAccurate") && cand[$ "isMostAccurate"] == true) {
                a = cand;
                break;
            }
        }
        if (!is_struct(a)) continue;
        var kms = 0;
        if (variable_struct_exists(a, "speed") && !is_undefined(a[$ "speed"])) kms = real(a[$ "speed"]);
        var note = donki_note_clean(struct_str(a, "note", ""));
        var when = start;
        var earth = donki_text_has(note, "EARTH");
        if (variable_struct_exists(a, "enlilList") && is_array(a[$ "enlilList"])) {
            var en = a[$ "enlilList"];
            for (var e = 0; e < array_length(en); e++) {
                var hit = en[e];
                if (!is_struct(hit)) continue;
                var loc = struct_str(hit, "location", struct_str(hit, "estimatedShockArrivalLocation", ""));
                var blob = loc + " " + struct_str(hit, "note", "");
                if (donki_text_has(blob, "EARTH") || variable_struct_exists(hit, "isEarthGB")) {
                    earth = true;
                    var arrv = struct_str(hit, "estimatedShockArrivalTime", "");
                    if (string_length(arrv) >= 10) when = arrv;
                }
            }
        }
        if (kms < 500) continue;
        if (donki_add_cme(when, kms, earth, note)) n += 1;
    }
    return n;
}

function donki_ingest_seps(arr) {
    if (!is_array(arr)) return 0;
    var n = 0;
    for (var i = 0; i < array_length(arr); i++) {
        var s = arr[i];
        if (!is_struct(s)) continue;
        var t = struct_str(s, "eventTime", struct_str(s, "t", ""));
        if (donki_add_sep(t, donki_note_clean(struct_str(s, "note", "")))) n += 1;
    }
    return n;
}

function donki_ingest_root(root) {
    if (is_array(root)) return donki_ingest_flares(root);
    if (!is_struct(root)) return 0;
    var n = 0;
    if (variable_struct_exists(root, "flares")) n += donki_ingest_flares(root[$ "flares"]);
    if (variable_struct_exists(root, "cmes")) n += donki_ingest_cmes(root[$ "cmes"]);
    if (variable_struct_exists(root, "seps")) n += donki_ingest_seps(root[$ "seps"]);
    return n;
}

function donki_load_snapshot() {
    var txt = donki_read_file("donki_snapshot.json");
    if (string_length(txt) < 2) {
        global.donki_status = "NO EMBEDDED CATALOG";
        return;
    }
    var data = undefined;
    try {
        data = json_parse(txt);
    } catch (e) {
        show_debug_message("DONKI snapshot parse failed");
        global.donki_status = "CATALOG UNREADABLE";
        return;
    }
    donki_ingest_root(data);
    global.donki_status = "DONKI CATALOG " + string(global.donki_flare_n) + " FLARES";
    show_debug_message(global.donki_status);
}

function donki_read_file(fn) {
    var paths = [working_directory + fn, working_directory + "datafiles/" + fn, program_directory + fn];
    for (var i = 0; i < array_length(paths); i++) {
        if (!file_exists(paths[i])) continue;
        var b = buffer_load(paths[i]);
        if (b < 0) continue;
        var s = buffer_read(b, buffer_text);
        buffer_delete(b);
        return s;
    }
    return "";
}

function donki_remote_url(kind) {
    var start = global.epoch;
    var now = today_clock_string();
    if (now < start) now = "2026-11-14";
    var endpoint = "https://ccmc.gsfc.nasa.gov/DONKI-API/get/" + kind + "?startDate=" + start + "&endDate=" + now;
    if (kind == "CME") endpoint += "&mostAccurateOnly=true";
    return endpoint;
}

function donki_queue(endpoint, kind, stage) {
    var req = http_get(endpoint);
    array_push(global.http_q, { id: req, kind: kind, stage: stage });
    show_debug_message("DONKI GET " + stage + " " + kind + " -> " + endpoint);
}

function donki_request_all() {
    var kinds = ["FLR", "CME", "SEP"];
    for (var i = 0; i < array_length(kinds); i++) {
        donki_queue("http://127.0.0.1:8771/" + kinds[i], kinds[i], "local");
    }
}

function donki_http_async() {
    if (!ds_exists(async_load, ds_type_map)) return;
    var req = async_load[? "id"];
    var idx = -1;
    for (var i = 0; i < array_length(global.http_q); i++) {
        if (global.http_q[i].id == req) { idx = i; break; }
    }
    if (idx < 0) return;
    var job = global.http_q[idx];
    array_delete(global.http_q, idx, 1);
    var status = async_load[? "status"];
    var http_status = async_load[? "http_status"];
    var result = async_load[? "result"];
    if (is_undefined(result)) result = "";
    var good = false;
    if (!is_undefined(http_status) && http_status >= 200 && http_status < 300) good = true;
    if (status == 0 || status == 200) good = true;
    if (!is_undefined(status) && status < 0) good = false;
    show_debug_message("DONKI " + job.kind + " " + job.stage + " status " + string(status) + " http " + string(http_status));
    if (!good) {
        if (job.stage == "local") donki_queue(donki_remote_url(job.kind), job.kind, "direct");
        else if (global.mode == "title" || global.mode == "play") log_line("DONKI " + job.kind + " LINK FAILED.");
        return;
    }
    var data = undefined;
    try {
        data = json_parse(result);
    } catch (e) {
        if (job.stage == "local") donki_queue(donki_remote_url(job.kind), job.kind, "direct");
        return;
    }
    var added = 0;
    if (job.kind == "FLR") added = donki_ingest_flares(data);
    else if (job.kind == "CME") added = donki_ingest_cmes(data);
    else if (job.kind == "SEP") added = donki_ingest_seps(data);
    if (job.kind == "FLR" && is_array(data)) {
        global.donki_live = true;
        global.donki_status = "LIVE DONKI  " + string(global.donki_flare_n) + " FLARES";
        if (added > 0) log_line("DONKI LIVE FLR +" + string(added) + ".");
        else log_line("DONKI LIVE MATCHES THE ONBOARD CATALOG.");
    } else if (added > 0) {
        global.donki_live = true;
        log_line("DONKI LIVE " + job.kind + " +" + string(added) + ".");
    }
}

function flare_band(cls) {
    var b = "?";
    var n = 0;
    if (string_length(cls) >= 1) b = string_upper(string_char_at(cls, 1));
    if (string_length(cls) >= 2) {
        var rest = string_delete(cls, 1, 1);
        if (string_length(rest) > 0) n = real(rest);
    }
    return { b: b, n: n };
}

function events_on_date(ymd) {
    var prompt = 0;
    var proton = 0;
    var lines = [];
    var significant = false;
    var headline = "QUIET";
    if (variable_struct_exists(global.donki_dates, ymd)) {
        var bucket = global.donki_dates[$ ymd];
        for (var i = 0; i < array_length(bucket.flares); i++) {
            var f = bucket.flares[i];
            var bm = flare_band(f.class);
            var bit = 0;
            if (bm.b == "C") bit = 0.15 + 0.04 * bm.n;
            else if (bm.b == "M") bit = 0.6 + 0.22 * bm.n;
            else if (bm.b == "X") bit = 2.5 * max(1, bm.n);
            prompt += bit;
            if (bm.b == "M" && f.alert) proton += 10 + bm.n * 2;
            if (bm.b == "X") proton += 25 * max(1, bm.n);
            if (bm.b == "X" || (bm.b == "M" && (f.alert || bm.n >= 1))) significant = true;
            var line = f.class;
            if (f.ar > 0) line += " AR" + string(floor(f.ar));
            if (string_length(f.loc) > 0) line += " " + f.loc;
            if (f.alert) line = "ALERT " + line;
            array_push(lines, line);
            if (headline == "QUIET" || f.alert || bm.b == "X" || bm.b == "M") headline = line;
        }
        for (var s = 0; s < array_length(bucket.seps); s++) {
            proton += 22;
            significant = true;
            array_push(lines, "SEP PROTON EVENT");
            headline = "SEP PROTON EVENT";
        }
        for (var c = 0; c < array_length(bucket.cmes); c++) {
            var cm = bucket.cmes[c];
            if (!cm.earth || cm.speed < 700) continue;
            var shock = min(8, cm.speed / 180);
            prompt += shock;
            if (cm.speed >= 900) significant = true;
            var cl = "CME " + string(floor(cm.speed)) + " KM/S";
            array_push(lines, cl);
            if (headline == "QUIET") headline = cl;
        }
    }
    if (proton > 60) proton = 60;
    if (prompt > 14) prompt = 14;
    if (proton >= 8) significant = true;
    return { prompt: prompt, proton: proton, fresh: proton, lines: lines, significant: significant, headline: headline };
}

function forecast_visible() {
    if (global.day <= 2) return true;
    return global.comms_up;
}

function announce_day() {
    var ymd = day_to_ymd(global.day);
    var ev = events_on_date(ymd);
    ev.proton += global.proton_carry;
    global.today = ev;
    global.alert = false;
    var see = forecast_visible();
    if (ev.significant) {
        if (see) {
            global.alert = true;
            global.logged += 1;
            global.paused = true;
            log_line("DONKI " + ymd + "  " + ev.headline);
            if (array_length(ev.lines) > 0) log_line(ev.lines[0]);
        } else {
            log_line("COMMS DARK ON " + ymd + ". NO DONKI LOCK.");
        }
    }
    if ((global.day mod 5) == 0) {
        global.paused = true;
        log_line("ASCENT WINDOW OPEN. A TO REACH ORBIT.");
    }
}
