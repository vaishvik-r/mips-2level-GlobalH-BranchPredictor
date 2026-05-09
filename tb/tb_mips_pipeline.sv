// tb_mips_pipeline.sv — Testbench for 5-stage MIPS pipeline
// Tests: basic R-type, load-use hazard, forwarding, beq/bne with predictor
`timescale 1ns/1ps

module tb_mips_pipeline;

    logic clk, rst;

    // Instantiate DUT
    mips_pipeline dut (.clk(clk), .rst(rst));

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // GTKWave dump
    initial begin
        $dumpfile("sim/mips_wave.vcd");
        $dumpvars(0, tb_mips_pipeline);
    end

    // ----------------------------------------------------------------
    // Load test program into instruction memory
    // Program tests:
    //   1. R-type: add $t2, $t0, $t1  (forwarding)
    //   2. Load-use: lw $t3,0($zero) then add $t4,$t3,$t0 (stall)
    //   3. beq: branch taken scenario  (predictor update)
    //   4. bne: branch not-taken scenario
    //   5. sw: store result
    // ----------------------------------------------------------------
    initial begin
        // Encoding MIPS instructions manually (hex)
        // Using addi to initialize registers first
        //
        // addi $t0, $zero, 5     → 0x20080005
        // addi $t1, $zero, 3     → 0x20090003
        // add  $t2, $t0,   $t1  → 0x01095020  (R-type)
        // sw   $t2, 0($zero)    → 0xAC0A0000  (store t2→mem[0])
        // lw   $t3, 0($zero)    → 0x8C0B0000  (load from mem[0] → t3)
        // add  $t4, $t3,   $t0  → 0x01685820  (load-use hazard: stall needed)
        // addi $t5, $zero, 5    → 0x200D0005
        // beq  $t0,  $t5,  +2  → 0x110D0002  (should be taken: t0==t5==5)
        // addi $t6, $zero, 99   → 0x200E0063  (skipped if branch taken)
        // addi $t6, $zero, 99   → 0x200E0063  (skipped)
        // addi $s0, $zero, 1    → 0x20100001  (branch target lands here)
        // bne  $t0,  $t1,  +1  → 0x150900001 (t0=5 != t1=3, taken)
        // addi $s1, $zero, 0    → 0x20110000  (skipped)
        // addi $s2, $zero, 42   → 0x20120002A (branch lands here)
        // nop (j to self)       → 0x08000009  (halt loop)
        // nop                   → 0x00000000

        dut.imem.mem[0]  = 32'h20080005; // addi $t0, $zero, 5
        dut.imem.mem[1]  = 32'h20090003; // addi $t1, $zero, 3
        dut.imem.mem[2]  = 32'h01095020; // add  $t2, $t0, $t1
        dut.imem.mem[3]  = 32'hAC0A0000; // sw   $t2, 0($zero)
        dut.imem.mem[4]  = 32'h8C0B0000; // lw   $t3, 0($zero)
        dut.imem.mem[5]  = 32'h01686020; // add  $t4, $t3, $t0  ← load-use stall
        dut.imem.mem[6]  = 32'h200D0005; // addi $t5, $zero, 5
        dut.imem.mem[7]  = 32'h110D0002; // beq  $t0, $t5, +2   ← taken (t0==t5)
        dut.imem.mem[8]  = 32'h200E0063; // addi $t6, $zero, 99 (should be flushed)
        dut.imem.mem[9]  = 32'h200E0063; // addi $t6, $zero, 99 (should be flushed)
        dut.imem.mem[10] = 32'h20100001; // addi $s0, $zero, 1  ← branch target
        dut.imem.mem[11] = 32'h15090001; // bne  $t0, $t1, +1   ← taken (5!=3)
        dut.imem.mem[12] = 32'h20110000; // addi $s1, $zero, 0  (flushed)
        dut.imem.mem[13] = 32'h2012002A; // addi $s2, $zero, 42 ← bne target
        dut.imem.mem[14] = 32'h0800000E; // j    14             (halt)
        dut.imem.mem[15] = 32'h00000000; // nop

        // Fill rest with NOPs
        begin : fill_nop
            integer i;
            for (i = 16; i < 256; i++)
                dut.imem.mem[i] = 32'h00000000;
        end
    end

    // ----------------------------------------------------------------
    // Simulation control
    // ----------------------------------------------------------------
    initial begin
        rst = 1;
        @(posedge clk); @(posedge clk);
        rst = 0;

        // Run for enough cycles to complete program
        repeat (60) @(posedge clk);

        // ---- Checks ----
        $display("=== MIPS Pipeline Simulation Results ===");
        $display("$t0 (reg 8)  = %0d  (expect 5)",  dut.rf.regs[8]);
        $display("$t1 (reg 9)  = %0d  (expect 3)",  dut.rf.regs[9]);
        $display("$t2 (reg 10) = %0d  (expect 8)",  dut.rf.regs[10]);
        $display("$t3 (reg 11) = %0d  (expect 8)",  dut.rf.regs[11]);
        $display("$t4 (reg 12) = %0d  (expect 13)", dut.rf.regs[12]); // load-use
        $display("$t5 (reg 13) = %0d  (expect 5)",  dut.rf.regs[13]);
        $display("$t6 (reg 14) = %0d  (expect 0,  NOT 99 — branch flushed)", dut.rf.regs[14]);
        $display("$s0 (reg 16) = %0d  (expect 1)",  dut.rf.regs[16]);
        $display("$s2 (reg 18) = %0d  (expect 42)", dut.rf.regs[18]);
        $display("");
        $display("=== Branch Predictor State ===");
        $display("GHR = %04b", dut.bp.ghr);
        $display("PHT[0] = %02b  PHT[1] = %02b  PHT[2] = %02b  PHT[3] = %02b",
                 dut.bp.pht[0], dut.bp.pht[1], dut.bp.pht[2], dut.bp.pht[3]);

        // Pass/fail
        if (dut.rf.regs[10] == 32'd8  &&
            dut.rf.regs[12] == 32'd13 &&
            dut.rf.regs[14] == 32'd0  &&
            dut.rf.regs[18] == 32'd42)
            $display("*** ALL CHECKS PASSED ***");
        else
            $display("*** SOME CHECKS FAILED — check waveform ***");

        $finish;
    end

    // Cycle counter for debug
    integer cycle_count = 0;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count < 65)
            $display("Cycle %0d | PC=%h | IF_instr=%h | stall=%b | branch_taken=%b | prediction=%b",
                     cycle_count, dut.pc, dut.instr,
                     dut.stall, dut.branch_taken, dut.prediction);
    end

endmodule
