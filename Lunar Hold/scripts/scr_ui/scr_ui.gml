function ui_hit(x, y, w, h, kind, a, b) {
    array_push(global.hits, { x: x, y: y, w: w, h: h, kind: kind, a: a, b: b });
}

function ui_button(x, y, w, h, text, enabled, kind, a, b) {
    var mx = device_mouse_x_to_gui(0);
    var my = device_mouse_y_to_gui(0);
    var hot = point_in_rectangle(mx, my, x, y, x + w, y + h);
    var fill = COL_PANEL;
    if (!enabled) fill = make_color_rgb(14, 16, 22);
    else if (hot) fill = make_color_rgb(22, 52, 56);
    var edge = enabled ? (hot ? COL_LINE : COL_DIML) : make_color_rgb(36, 42, 48);
    draw_set_alpha(1);
    draw_set_color(fill);
    draw_rectangle(x, y, x + w, y + h, false);
    draw_set_color(edge);
    draw_rectangle(x, y, x + w, y + h, true);
    draw_set_color(enabled ? COL_TEXT : COL_DIM);
    draw_text(x + 8, y + 5, text);
    if (enabled) ui_hit(x, y, w, h, kind, a, b);
}

function ui_act(h) {
    switch (h.kind) {
        case "begin":
            start_run();
            break;
        case "help":
            global.help = !global.help;
            if (global.help && global.mode == "play") global.paused = true;
            break;
        case "closehelp":
            global.help = false;
            break;
        case "ascend":
            try_ascend();
            break;
        case "power":
            toggle_power(h.a);
            break;
        case "build":
            begin_build(h.a, h.b);
            break;
        case "crew":
            if (!global.crew[h.a].alive) break;
            if (global.crew_sel == h.a) global.crew_sel = -1;
            else global.crew_sel = h.a;
            break;
        case "pad":
            if (global.crew_sel >= 0 && global.pads[h.a].phase != "empty") assign_crew(global.crew_sel, h.a);
            else global.sel = h.a;
            break;
        case "recall":
            if (global.crew_sel >= 0) assign_crew(global.crew_sel, 4);
            break;
        case "speed":
            global.spd = h.a;
            break;
        case "pause":
            global.paused = !global.paused;
            break;
        case "again":
            start_run();
            break;
        case "title":
            global.mode = "title";
            global.help = false;
            break;
    }
}

function ui_dispatch() {
    if (!global.ui_click) return;
    var mx = device_mouse_x_to_gui(0);
    var my = device_mouse_y_to_gui(0);
    for (var i = array_length(global.hits) - 1; i >= 0; i--) {
        var h = global.hits[i];
        if (point_in_rectangle(mx, my, h.x, h.y, h.x + h.w, h.y + h.h)) {
            ui_act(h);
            global.ui_click = false;
            return;
        }
    }
}
