function String toHex(Bit#(s) num);
    function String f(Bit#(s) n);
        String dig[16] = {"0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"};
        return (n == 0) ? "" : f(n / 16) + dig[n % 16];
    endfunction
    return (num == 0) ? "0" : f(num);
endfunction
