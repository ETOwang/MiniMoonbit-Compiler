
function ack(x, y) {
    if (x <= 0) {
        return y + 1;
    } else {
        if (y <= 0) {
            return ack(x - 1, 1);
        } else {
            return ack(x - 1, ack(x, y - 1));
        }
    }
}

function main() {
    minimbt_print_int(ack(3, 8));
    minimbt_print_endline();
}

export default main;