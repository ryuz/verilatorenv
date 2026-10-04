module smoke(input logic signal_in, output logic signal_out);
    assign signal_out = ~signal_in;
endmodule