
function sum(x) {
    if (x <= 0) {
        return 0;
    } else {
        return sum(x - 1) + x;
    }
}

function main() {
    minimbt_print_int(sum(10));
    minimbt_print_endline();
}

export default main;