fn getx(v : (Double, Double, Double)) -> Double {
  let (x, _, _) = v
  x
}

fn inprod(
  v1 : (Double, Double, Double),
  v2 : (Double, Double, Double)
) -> Double {
  getx(v1) * getx(v2)
}

fn main {
  print_int(truncate(1000000.0 * inprod((1.0, 2.0, 3.0), (4.0, 5.0, 6.0))))
}
