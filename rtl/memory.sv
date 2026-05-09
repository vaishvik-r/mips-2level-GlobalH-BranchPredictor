// memory.sv — Instruction Memory and Data Memory

// Instruction Memory — ROM, word-addressed
module instr_mem #(parameter DEPTH = 256) (
    input  logic [31:0] addr,
    output logic [31:0] instr
);
    logic [31:0] mem [0:DEPTH-1];

    initial $readmemh("program.hex", mem);

    assign instr = mem[addr[31:2]]; // word-aligned
endmodule

// Data Memory — single-port RAM
module data_mem #(parameter DEPTH = 256) (
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);
    logic [31:0] mem [0:DEPTH-1];

    initial begin
        integer i;
        for (i = 0; i < DEPTH; i++) mem[i] = 32'd0;
    end

    assign read_data = mem_read ? mem[addr[31:2]] : 32'd0;

    always_ff @(posedge clk) begin
        if (mem_write)
            mem[addr[31:2]] <= write_data;
    end
endmodule
