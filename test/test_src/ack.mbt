fn ack(x : Int, y : Int) -> Int {
    fn g(z: Int) -> Int {
        let r = x+y;
        if not(z <= 0) {
            1
        } else {
            g(-z)
        }
    };
    g(1)
};

fn main {
  print_int(ack(3,8))
};