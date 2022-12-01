module RiscvMem #(
    int MEM_DEPTH = 256
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

always @(posedge clk) begin
    if (read) begin
        rData <= mem[addr[2+:MEM_IDX_W]];
    end
    for (int i=0; i<4; i++) begin
        if (wStrb[i]) mem[addr[2+:MEM_IDX_W]][8*i+:8] <= wData[8*i+:8];
    end
    if (!rstn) rData <= '0;
end

initial begin
    // I probably shouldn't have to do it this way... but the "verilog" output 
    // is byte-oriented and I need to arrange it like this. Unless I figure out 
    // a different way for objcopy to declare the offsets correctly. Whatever.
    automatic bit [7:0] memload [MEM_DEPTH*4];
    $readmemh("prog.mem", memload);
    for (int i=0; i<MEM_DEPTH*4; i+=4) begin
        mem[i>>2] = {memload[i+3],memload[i+2],memload[i+1],memload[i]};
    end
    // Debug for checking the memory content
    /*
    for (int i=0; i<MEM_DEPTH; i++) begin
        if (i%4 == 0) $write("%4x: ", i<<2);
        $write("%x ", mem[i]);
        if (i%4 == 3) $write("\n");
    end
    */
end

endmodule
