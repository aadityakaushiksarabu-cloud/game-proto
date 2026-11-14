boot_game();
global.autoplay = (environment_get_variable("LUNAR_AUTOPLAY") == "1");
display_set_gui_size(1280, 720);
window_set_caption("Lunar Hold");
window_set_size(1280, 720);
window_center();
