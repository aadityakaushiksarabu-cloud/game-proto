global.ui_click = mouse_check_button_pressed(mb_left);
if (global.autoplay && global.mode == "title") {
    global.autoplay = false;
    start_run();
}
sim_step();
