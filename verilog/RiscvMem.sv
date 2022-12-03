module RiscvMem #(
    parameter INIT_FILE = "",
    parameter int MEM_DEPTH = 1024
)
(
    input logic clk,
    input logic rstn,
    input logic [31:0] addr,
    input logic read,
    input logic [3:0] wStrb,
    input logic [31:0] wData,
    output logic [31:0] rData
);

localparam MEM_IDX_W = $clog2(MEM_DEPTH);

logic [31:0] mem [MEM_DEPTH];

// Byte reversal
logic [31:0] memOut;
logic [31:0] memIn;
logic [3:0] strobeIn;
always_comb for (int i=0; i<4; i++) rData[8*i+:8] = memOut[8*(3-i)+:8];
always_comb for (int i=0; i<4; i++) memIn[8*(3-i)+:8] = wData[8*i+:8];
always_comb for (int i=0; i<4; i++) strobeIn[3-i] = wStrb[i];

if (INIT_FILE != "") begin
    initial begin
        $readmemh(INIT_FILE, mem);
        /*
        // Debug for checking the memory content
        for (int i=0; i<MEM_DEPTH; i++) begin
            if (i%4 == 0) $write("%4x: ", i<<2);
            $write("%x ", mem[i]);
            if (i%4 == 3) $write("\n");
        end
        */
    end
end
else begin
    initial for (int i=0; i<MEM_DEPTH; i++) mem[i] = '0;
end

always @(posedge clk) begin
    // Write path
    for (int i=0; i<4; i++) begin
        if (strobeIn[i]) mem[addr[2+:MEM_IDX_W]][8*i+:8] <= memIn[8*i+:8];
    end
    if (read) memOut <= mem[addr[2+:MEM_IDX_W]];
end

endmodule
