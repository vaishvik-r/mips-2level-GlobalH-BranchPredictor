// control.sv — Main Control Unit (decodes opcode)
module control (
    input  logic [5:0]  opcode,
    output logic        reg_dst, alu_src, mem_to_reg,
    output logic        reg_write, mem_read, mem_write,
    output logic        branch, jump,
    output logic [1:0]  alu_op
);
    always_comb begin
        // defaults
        {reg_dst, alu_src, mem_to_reg, reg_write,
         mem_read, mem_write, branch, jump} = 8'b0;
        alu_op = 2'b00;

        case (opcode)
            6'b000000: begin // R-type
                reg_dst   = 1; reg_write = 1;
                alu_op    = 2'b10;
            end
            6'b100011: begin // lw
                alu_src   = 1; mem_to_reg = 1;
                reg_write = 1; mem_read   = 1;
                alu_op    = 2'b00;
            end
            6'b101011: begin // sw
                alu_src   = 1; mem_write  = 1;
                alu_op    = 2'b00;
            end
            6'b000100: begin // beq
                branch    = 1;
                alu_op    = 2'b01;
            end
            6'b000101: begin // bne
                branch    = 1;
                alu_op    = 2'b01;
            end
            6'b001000: begin // addi
                alu_src   = 1; reg_write  = 1;
                alu_op    = 2'b00;
            end
            6'b001101: begin // ori
                alu_src   = 1; reg_write  = 1;
                alu_op    = 2'b11;
            end
            6'b001010: begin // slti
                alu_src   = 1; reg_write  = 1;
                alu_op    = 2'b10;
            end
            6'b000010: begin // j
                jump      = 1;
            end
            6'b000011: begin // jal
                jump      = 1; reg_write  = 1;
            end
            default: ;
        endcase
    end
endmodule
