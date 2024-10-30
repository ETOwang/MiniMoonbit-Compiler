fn ack(x : Int, y : Int) -> Int {
  fn add(z, w) {
    z + w
  }

  add(x, y)
}

fn main {
  print_int(ack(3, 8))
}
