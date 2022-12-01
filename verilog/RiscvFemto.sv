`default_nettype none
module RiscvFemto (
    input var logic clk,
    input var logic rstn,
    input var logic [31:0] memIn,
    output var logic [31:0] memAddr,
    output var logic memRead,
    output var logic [3:0] memWstrb,
    output var logic [31:0] memWrite
);

logic [31:0] instr = '0;
logic [31:0] pc = '0;

logic signed [31:0] regFile [32];
logic signed [31:0] rs1 = '0;
logic signed [31:0] rs2 = '0;

initial begin
    for (int i=0; i<32; i++) regFile[i] = '0;
end

///////////////////////////////////////////////////////////////////////////////
// Instruction decode
///////////////////////////////////////////////////////////////////////////////

wire isAluReg = (instr[6:0] == 7'b01_100_11); // rd <- rs1 OP rs2
wire isAluImm = (instr[6:0] == 7'b00_100_11); // rd <- rs1 OP immI
wire isBranch = (instr[6:0] == 7'b11_000_11); // if(rs1 OP rs2) pc <- pc+immB
wire isJalr   = (instr[6:0] == 7'b11_001_11); // rd <- pc+4; pc <- rs1+immI
wire isJal    = (instr[6:0] == 7'b11_011_11); // rd <- pc+4; pc <- pc+immJ
wire isAuiPc  = (instr[6:0] == 7'b00_101_11); // rd <- pc + immU
wire isLui    = (instr[6:0] == 7'b01_101_11); // rd <- immU
wire isLoad   = (instr[6:0] == 7'b00_000_11); // rd <- mem[rs1+immI]
wire isStore  = (instr[6:0] == 7'b01_000_11); // mem[rs1+immS] <- rs2
wire isSystem = (instr[6:0] == 7'b11_100_11); // SYSTEM calls
wire [4:0] rs1Id = instr[19:15];
wire [4:0] rs2Id = instr[24:20];
wire [4:0] rdId = instr[11:7];
wire [2:0] funct3 = instr[14:12];
wire [6:0] funct7 = instr[31:25];
wire signed [31:0] immU = signed'({instr[31], instr[30:12], 12'b0});
wire signed [31:0] immI = signed'({instr[31], instr[30:20]});
wire signed [31:0] immS = signed'({instr[31], instr[30:25], instr[11:7]});
wire signed [31:0] immB = signed'({instr[31], instr[7], instr[30:25], instr[11:8], 1'b0});
wire signed [31:0] immJ = signed'({instr[31], instr[19:12], instr[20], instr[30:21], 1'b0});

///////////////////////////////////////////////////////////////////////////////
// ALU
///////////////////////////////////////////////////////////////////////////////

wire signed [31:0] aluIn1 = rs1;
wire signed [31:0] aluIn2 = (isAluReg | isBranch) ? rs2 : immI;
logic signed [31:0] aluOut;

// Add/Subtract
wire aluSubtract = (isAluReg && funct7[5]) || isBranch;
wire signed [32:0] aluAdder = aluSubtract ? (aluIn1-aluIn2) : (aluIn1+aluIn2);
wire aluEq = aluAdder[31:0] == 32'd0;
wire aluLtu = aluIn1[31] ^ aluIn2[31] ^ aluAdder[32];
wire aluLt = aluAdder[32];
logic takeBranch;

// Shift reg
wire [4:0] shamt = aluIn2[4:0];
wire [31:0] flipAluIn1;
for (genvar i=0; i<32; i++) assign flipAluIn1[i] = aluIn1[31-i];
wire [31:0] shifterIn = (funct3 == 3'b001) ? flipAluIn1 : aluIn1;
wire [31:0] shifter = signed'({funct7[5]&aluIn1[31], shifterIn}) >>> shamt;
wire [31:0] leftShift;
for (genvar i=0; i<32; i++) assign leftShift[i] = shifter[31-i];

always_comb begin
    case (funct3)
        3'b000: aluOut = aluAdder;
        3'b001: aluOut = leftShift;
        3'b010: aluOut = {31'b0, aluLt};
        3'b011: aluOut = {31'b0, aluLtu};
        3'b100: aluOut = aluIn1 ^ aluIn2;
        3'b101: aluOut = shifter;
        3'b110: aluOut = aluIn1 | aluIn2;
        3'b111: aluOut = aluIn1 & aluIn2;
    endcase
end

always_comb begin
    case(funct3)
        3'b000: takeBranch = aluEq;
        3'b001: takeBranch = !aluEq;
        3'b100: takeBranch = aluLt;
        3'b101: takeBranch = !aluLt;
        3'b110: takeBranch = aluLtu;
        3'b111: takeBranch = !aluLtu;
        default: takeBranch = 1'b0;
    endcase
end

`ifdef SIM
always @(posedge clk) begin
    if (aluSubtract && (aluLtu != (unsigned'(aluIn1) < unsigned'(aluIn2)))) begin
        $error("aluLtu check failed");
    end
    if (aluSubtract && (aluLt != (aluIn1 < aluIn2))) begin
        $error("aluLt check failed");
    end
end
`endif

///////////////////////////////////////////////////////////////////////////////
// State Machine & Load/Store
///////////////////////////////////////////////////////////////////////////////

enum {
    ST_FETCH_INSTR,
    ST_WAIT_INSTR,
    ST_FETCH_REGS,
    ST_EXECUTE,
    ST_LOAD,
    ST_WAIT_DATA,
    ST_STORE
} state;
initial state = ST_FETCH_INSTR;

wire [31:0] loadstoreAddr = rs1 + (isStore ? immS : immI);

// Load memory mapping
wire memByteAccess = funct3[1:0] == 2'b00;
wire memHalfwordAccess = funct3[1:0] == 2'b01;
wire [15:0] loadHalfword = loadstoreAddr[1] ? memIn[31:16] : memIn[15:0];
wire [7:0] loadByte = loadstoreAddr[0] ? loadHalfword[15:8] : loadHalfword[7:0];
wire loadSign = !funct3[2] & (memByteAccess ? loadByte[7] : loadHalfword[15]);
wire [31:0] loadData = memByteAccess ? {{24{loadSign}}, loadByte}
    : memHalfwordAccess ? {{16{loadSign}}, loadHalfword}
    : memIn;

// Store memory mapping
assign memWrite[ 7: 0] = rs2[7:0];
assign memWrite[15: 8] = loadstoreAddr[0] ? rs2[7:0] : rs2[15: 8];
assign memWrite[23:16] = loadstoreAddr[1] ? rs2[7:0] : rs2[23:16];
assign memWrite[31:24] = loadstoreAddr[0] ? rs2[7:0]
    : loadstoreAddr[1] ? rs2[15:8] : rs2[31:24];
wire [3:0] storeMask = memByteAccess
    ? (loadstoreAddr[1]
        ? (loadstoreAddr[0] ? 4'b1000 : 4'b0100)
        : (loadstoreAddr[0] ? 4'b0010 : 4'b0001)
    )
    : memHalfwordAccess ? (loadstoreAddr[1] ? 4'b1100 : 4'b0011)
    : 4'b1111;

// Program counter calculation
wire [31:0] pcPlus4 = pc + 4;
wire [31:0] pcPlusImm = pc + (instr[3] ? immJ : instr[4] ? immU : immB);
wire [31:0] nextPC = (isBranch && takeBranch || isJal) ? pcPlusImm
    : isJalr ? {aluAdder[31:1], 1'b0}
    : pcPlus4;

// Register Writeback
wire [31:0] writeBackData = (isJal || isJalr) ? pcPlus4
    : isLoad ? loadData
    : isLui ? immU
    : isAuiPc ? pcPlusImm
    : aluOut;
wire writeBackEn = (state == ST_EXECUTE && !isBranch && !isStore && !isLoad)
    || (state == ST_WAIT_DATA);

// Memory read/write
assign memAddr = (state == ST_FETCH_INSTR || state == ST_WAIT_INSTR) ? pc : loadstoreAddr;
assign memRead = state == ST_FETCH_INSTR || state == ST_LOAD;
assign memWstrb = (state == ST_STORE) ? storeMask : '0;

// Main state sequence & register storage
always @(posedge clk) begin
    if (writeBackEn && (rdId != 0)) regFile[rdId] <= writeBackData;
    case(state)
        ST_FETCH_INSTR: state <= ST_WAIT_INSTR;
        ST_WAIT_INSTR: begin
            instr <= memIn;
            state <= ST_FETCH_REGS;
        end
        ST_FETCH_REGS: begin
            rs1 <= regFile[rs1Id];
            rs2 <= regFile[rs2Id];
            state <= ST_EXECUTE;
        end
        ST_EXECUTE: begin
            if (!isSystem) pc <= nextPC;
            state <= isLoad ? ST_LOAD 
                : isStore ? ST_STORE
                : ST_FETCH_INSTR;
        end
        ST_LOAD: state <= ST_WAIT_DATA;
        ST_WAIT_DATA: state <= ST_FETCH_INSTR;
        ST_STORE: state <= ST_FETCH_INSTR;
    endcase
    if (!rstn) begin
        pc <= '0;
        state <= ST_FETCH_INSTR;
    end
end


endmodule
`default_nettype wire
