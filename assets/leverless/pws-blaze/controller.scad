// 部品は印刷姿勢。assemblyだけ組立座標: X=左右、Y=手前→奥、Z=高さ。
part = "assembly"; // [assembly,frame,top_left,top_right,bottom,corner_post,corner_post_right,center_post,corner_nut_plug,center_nut_plug,wall,wall_usb,button_layout]

include <../../../modules/leverless_pws_blaze.scad>

if (part == "assembly") assembly();
else if (part == "frame") frame();
else if (part == "top_left") plate();
else if (part == "top_right") plate(right = true);
else if (part == "bottom") plate(bottom = true);
else if (part == "corner_post") post();
else if (part == "corner_post_right") translate([2 * post_w, 0, 0]) mirror([1, 0, 0]) post();
else if (part == "center_post") post(center = true);
else if (part == "corner_nut_plug") nut_plug(corner = true);
else if (part == "center_nut_plug") nut_plug();
else if (part == "wall") wall();
else if (part == "wall_usb") wall(usb = true);
else if (part == "button_layout") {
  echo(buttons_left = buttons_left, buttons_right = buttons_right);
  echo(pcb_mounts_left = pcb_mounts_left);
  echo(pcb_mounts_right = pcb_mounts_right);
  projection() for (right = [false, true]) translate([right ? half_w : 0, 0, 0]) plate(right = right);
}
else assert(false, str("Unknown part: ", part));
