// forwarding_unit.sv — EX-EX and MEM-EX forwarding paths
module forwarding_unit (
    input  logic [4:0] ex_mem_rd,
    input  logic       ex_mem_reg_write,
    input  logic [4:0] mem_wb_rd,
    input  logic       mem_wb_reg_write,
    input  logic [4:0] id_ex_rs,
    input  logic [4:0] id_ex_rt,
    output logic [1:0] forward_a,  // mux select for ALU input A
    output logic [1:0] forward_b   // mux select for ALU input B
);
    // forward_a / forward_b encoding:
    //   2'b00 = from register file (no forwarding)
    //   2'b10 = EX-EX forward (from EX/MEM pipeline register)
    //   2'b01 = MEM-WB forward (from MEM/WB pipeline register)

    always_comb begin
        // Forward A
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rs)
            forward_a = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rs)
            forward_a = 2'b01;
        else
            forward_a = 2'b00;

        // Forward B
        if (ex_mem_reg_write && ex_mem_rd != 5'd0 && ex_mem_rd == id_ex_rt)
            forward_b = 2'b10;
        else if (mem_wb_reg_write && mem_wb_rd != 5'd0 && mem_wb_rd == id_ex_rt)
            forward_b = 2'b01;
        else
            forward_b = 2'b00;
    end
endmodule
