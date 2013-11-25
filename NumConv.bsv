function Bit#(n) removeDontCares(Bit#(n) num);
    Bit#(n) res = 0;
    for(Integer i = 0; i < valueOf(n); i = i + 1)
        res[i] = (case(num[i]) matches
            1'b0: 1'b0;
            1'b1: 1'b1;
            default: 1'b0;
        endcase);
    return res;
endfunction

function String toHex(Bit#(n) num);
    function String f(Bit#(n) x);
        String dig[16] = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"};
        return (x == 0) ? "" : (valueOf(n) < 5) ? dig[x] : f(x / 16) + dig[x % 16];
    endfunction
    Bit#(n) clean = removeDontCares(num);
    return (clean == 0) ? "0" : f(clean);
endfunction
