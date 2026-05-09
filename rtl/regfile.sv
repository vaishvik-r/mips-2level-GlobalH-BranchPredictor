// regfile.sv — 32x32 Register File (R0 hardwired to 0)
module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  rs, rt, rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1, rd2
);
    logic [31:0] regs [31:0];

    // R0 always 0
    initial begin
        integer i;
        for (i = 0; i < 32; i++) regs[i] = 32'd0;
    end

    assign rd1 = (rs == 5'd0) ? 32'd0 : regs[rs];
    assign rd2 = (rt == 5'd0) ? 32'd0 : regs[rt];

    always_ff @(posedge clk) begin
        if (we && rd != 5'd0)
            regs[rd] <= wd;
    end
endmodule
