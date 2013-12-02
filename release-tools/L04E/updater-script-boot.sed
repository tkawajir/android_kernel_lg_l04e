assert(getprop("ro.build.product") == "geevl04e");
ui_print("");
ui_print("");
ui_print("");
show_progress(0.500000, 0);

ui_print("flashing boot image...");
package_extract_file("boot.img", "/dev/block/mmcblk0p7");
show_progress(0.100000, 0);

ui_print("flash complete. Enjoy!");
set_progress(1.000000);

