$fn = 64;

height = 20;
inner_d = 4;
outer_d = 10;

difference() {
  cylinder(h = height, d = outer_d);
  cylinder(h = height, d = inner_d);
}
