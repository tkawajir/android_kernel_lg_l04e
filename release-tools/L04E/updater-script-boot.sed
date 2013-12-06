getprop("ro.build.product")
assert(getprop("ro.build.product") == "geevl04e");
ui_print("");
ui_print("");
ui_print("");
show_progress(0.500000, 0);

ui_print("flashing boot image...");
run_program("loki_flash", "boot", "boot.lok");
show_progress(0.100000, 0);

ui_print("flash complete. Enjoy!");
set_progress(1.000000);

