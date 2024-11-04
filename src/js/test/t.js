function loop3(i,j,k,a,b,c) {
if (0 <= k) { 
c[i][j] = (c[i][j] + (a[i][k] * b[k][j]));
return loop3(i, j, (k - 1), a, b, c);
} else { 
return ;
}
}
function loop2(i,m,j,a,b,c) {
if (0 <= j) { 
let tempvar1 = loop3(i, j, (m - 1), a, b, c)
return loop2(i, m, (j - 1), a, b, c);
} else { 
return ;
}
}
function loop1(i,m,n,a,b,c) {
if (0 <= i) { 
let tempvar2 = loop2(i, m, (n - 1), a, b, c)
return loop1((i - 1), m, n, a, b, c);
} else { 
return ;
}
}
function mul(l,m,n,a,b,c) {
let tempvar3 = loop1((l - 1), m, n, a, b, c)
return 
}
function main() {
let dummy = Array(0).fill(0)
function init_arr(i,n,mat) {
if (0 <= i) { 
mat[i] = Array(n).fill(0);
return init_arr((i - 1), n, mat);
} else { 
return ;
}
}
function make_arr(m,n,dummy) {
let mat = Array(m).fill(dummy)
let tempvar4 = init_arr((m - 1), n, mat)
return mat
}
let a = make_arr(2, 3, dummy)
let b = make_arr(3, 2, dummy)
let c = make_arr(2, 2, dummy)
a[0][0] = 1;
a[0][1] = 2;
a[0][2] = 3;
a[1][0] = 4;
a[1][1] = 5;
a[1][2] = 6;
b[0][0] = 7;
b[0][1] = 8;
b[1][0] = 9;
b[1][1] = 10;
b[2][0] = 11;
b[2][1] = 12;
let tempvar5 = mul(2, 3, 2, a, b, c)
let tempvar6 = minimbt_print_int(minimbt_truncate(c[0][0]))
let tempvar7 = minimbt_print_endline()
let tempvar8 = minimbt_print_int(minimbt_truncate(c[0][1]))
let tempvar9 = minimbt_print_endline()
let tempvar10 = minimbt_print_int(minimbt_truncate(c[1][0]))
let tempvar11 = minimbt_print_endline()
let tempvar12 = minimbt_print_int(minimbt_truncate(c[1][1]))
;
minimbt_print_endline();
}

export default main;