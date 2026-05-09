// alu_control.sv — Generates 4-bit ALU control from ALUOp + funct
module alu_control (
    input  logic [1:0] alu_op,
    input  logic [5:0] funct,
    output logic [3:0] alu_ctrl
);
    always_comb begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0010; // ADD (lw/sw/addi)
            2'b01: alu_ctrl = 4'b0110; // SUB (beq/bne)
            2'b11: alu_ctrl = 4'b0001; // OR  (ori)
            2'b10: begin               // R-type / slti
                case (funct)
                    6'b100000: alu_ctrl = 4'b0010; // add
                    6'b100010: alu_ctrl = 4'b0110; // sub
                    6'b100100: alu_ctrl = 4'b0000; // and
                    6'b100101: alu_ctrl = 4'b0001; // or
                    6'b101010: alu_ctrl = 4'b0111; // slt
                    6'b100111: alu_ctrl = 4'b1100; // nor
                    6'b100110: alu_ctrl = 4'b0011; // xor
                    default:   alu_ctrl = 4'b0010;
                endcase
            end
            default: alu_ctrl = 4'b0010;
        endcase
    end
endmodule
