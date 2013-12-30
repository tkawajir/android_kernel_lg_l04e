assert(getprop("ro.build.product") == "geevl04e" || getprop("ro.product.device") == "geevl04e");
ui_print("");
ui_print("");
ui_print("------------------------------------------------");
ui_print("@VERSION");
ui_print("  tkawajir");
ui_print("------------------------------------------------");
ui_print("");
show_progress(0.500000, 0);

ui_print("flashing boot image...");
package_extract_file("boot.img", "/tmp/boot.img");
assert(run_program("/system/bin/loki.sh") == 0);
show_progress(0.100000, 0);

ui_print("flash complete. Enjoy!");
set_progress(1.000000);

