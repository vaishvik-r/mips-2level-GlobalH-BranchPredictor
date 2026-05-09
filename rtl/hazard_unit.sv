// hazard_unit.sv — Detects load-use hazards and generates stall signals
module hazard_unit (
    input  logic [4:0] id_ex_rt,
    input  logic       id_ex_mem_read,
    input  logic [4:0] if_id_rs,
    input  logic [4:0] if_id_rt,
    output logic       stall        // stall IF and ID, insert bubble into EX
);
    // Load-use hazard: instruction after lw uses the loaded register
    assign stall = id_ex_mem_read &&
                   ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt));
endmodule
