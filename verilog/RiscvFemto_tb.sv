module RiscvFemto_tb ();

logic clk = 1'b0;
logic rstn = 1'b1;
logic [31:0] memIn;
logic [31:0] memAddr;
logic memRead;
logic [3:0] memWstrb;
logic [31:0] memWrite;
logic [31:0] memRData;

logic tx;
logic [7:0] leds = '0;

logic uatReady;
logic uatWrite;
wire isMem = !memAddr[22];

always #1 clk = ~clk;

RiscvFemto uut ( .* );
RiscvMem #( 256 ) memory (
    .clk(clk),
    .rstn(rstn),
    .addr(memAddr),
    .read(memRead & isMem),
    .wStrb({4{isMem}} & memWstrb),
    .wData(memWrite),
    .rData(memRData)
);

always @(posedge clk) begin
    if (!isMem && memAddr[2] && memWstrb[0]) leds <= memWrite;
end

assign uatWrite = !isMem && memAddr[3] && memWstrb[0];
assign memIn = isMem ? memRData
    : memAddr[4] ? {22'd0, uatReady, 9'd0}
    : 32'd0;

RiscvUAT #( 500_000_000, 50_000_000) uat0 (
    .clk(clk),
    .rstn(rstn),
    .dIn(memWrite[7:0]),
    .dInValid(uatWrite),
    .dInReady(uatReady),
    .tx(tx)
);

// Display UAT output
always @(posedge clk) begin
    if (uatWrite && uatReady) begin
        $write("%c", memWrite[7:0]);
        $fflush(32'h8000_0001);
    end
end

wire [31:0] regFile0  = uut.regFile[ 0];
wire [31:0] regFile1  = uut.regFile[ 1];
wire [31:0] regFile2  = uut.regFile[ 2];
wire [31:0] regFile3  = uut.regFile[ 3];
wire [31:0] regFile4  = uut.regFile[ 4];
wire [31:0] regFile5  = uut.regFile[ 5];
wire [31:0] regFile6  = uut.regFile[ 6];
wire [31:0] regFile7  = uut.regFile[ 7];
wire [31:0] regFile8  = uut.regFile[ 8];
wire [31:0] regFile9  = uut.regFile[ 9];
wire [31:0] regFile10 = uut.regFile[10];
wire [31:0] regFile11 = uut.regFile[11];
wire [31:0] regFile12 = uut.regFile[12];
wire [31:0] regFile13 = uut.regFile[13];
wire [31:0] regFile14 = uut.regFile[14];
wire [31:0] regFile15 = uut.regFile[15];
wire [31:0] regFile16 = uut.regFile[16];
wire [31:0] regFile17 = uut.regFile[17];
wire [31:0] regFile18 = uut.regFile[18];
wire [31:0] regFile19 = uut.regFile[19];
wire [31:0] regFile20 = uut.regFile[20];
wire [31:0] regFile21 = uut.regFile[21];
wire [31:0] regFile22 = uut.regFile[22];
wire [31:0] regFile23 = uut.regFile[23];
wire [31:0] regFile24 = uut.regFile[24];
wire [31:0] regFile25 = uut.regFile[25];
wire [31:0] regFile26 = uut.regFile[26];
wire [31:0] regFile27 = uut.regFile[27];
wire [31:0] regFile28 = uut.regFile[28];
wire [31:0] regFile29 = uut.regFile[29];
wire [31:0] regFile30 = uut.regFile[30];
wire [31:0] regFile31 = uut.regFile[31];

initial begin
    $dumpfile("RiscvFemto_tb.vcd");
    $dumpvars(0, uut, uut.pc, leds, tx, uat0,
        regFile0 , regFile1 , regFile2 , regFile3 ,
        regFile4 , regFile5 , regFile6 , regFile7 ,
        regFile8 , regFile9 , regFile10, regFile11,
        regFile12, regFile13, regFile14, regFile15,
        regFile16, regFile17, regFile18, regFile19,
        regFile20, regFile21, regFile22, regFile23,
        regFile24, regFile25, regFile26, regFile27,
        regFile28, regFile29, regFile30, regFile31
    );
    #100000 $finish;
end

endmodule
