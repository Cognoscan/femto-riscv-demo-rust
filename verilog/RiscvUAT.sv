module RiscvUAT #(
    int CLK_FREQ = 50_000_000,
    int BAUD = 57600
)
(
    input logic clk,
    input logic rstn,
    input logic [7:0] dIn,
    input logic dInValid,
    output logic dInReady,
    output logic tx
);

localparam COUNT = CLK_FREQ/BAUD;
localparam CNT_W = $clog2(COUNT)+1;

logic [CNT_W-1:0] clkDiv = '1;
logic [8:0] shift = '0;

initial begin
    tx = 1'b1;
    dInReady = 1'b0;
end

always @(posedge clk) begin
    if (|shift) begin
        dInReady <= 1'b0;
        if (clkDiv[CNT_W-1]) begin
            clkDiv <= COUNT;
            {shift, tx} <= {1'b0, shift};
        end
        else begin
            clkDiv <= clkDiv - 1;
        end
    end
    else begin
        if (clkDiv[CNT_W-1] && dInValid && dInReady) begin
            dInReady <= 1'b0;
            clkDiv <= COUNT;
            {shift, tx} <= {1'b1, dIn, 1'b0};
        end
        else if (clkDiv[CNT_W-1]) begin
            dInReady <= 1'b1;
            {shift, tx} <= 1;
        end
        else begin
            dInReady <= 1'b0;
            clkDiv <= clkDiv - 1;
        end
    end
    if (!rstn) begin
        shift <= '0;
        clkDiv <= '1;
    end
end

endmodule
