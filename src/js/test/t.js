function f(n) {
if (!0 <= n) { 
return ;
} else { 
let t1 = minimbt_print_int(n)
let a = Array(1).fill(f)
let a0 = a[0]
return a0((n - 1));
}
}
function main() {
f(9);
minimbt_print_endline();
}

export default main;