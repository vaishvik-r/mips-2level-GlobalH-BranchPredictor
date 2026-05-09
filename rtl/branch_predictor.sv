// branch_predictor.sv — Two-Level Adaptive Branch Predictor (GAg)
// Global History Register (GHR) + Pattern History Table (PHT)
// GHR: 4-bit shift register tracking last 4 branch outcomes
// PHT: 16-entry table of 2-bit saturating counters, indexed by GHR
module branch_predictor (
    input  logic        clk,
    input  logic        rst,
    // Prediction interface (IF stage)
    input  logic        is_branch,       // current instruction is a branch
    output logic        prediction,      // 1=taken, 0=not-taken
    // Update interface (ID/EX stage — when branch resolves)
    input  logic        update_en,       // branch resolved, update now
    input  logic        actual_outcome   // 1=taken, 0=not-taken
);
    // ----------------------------------------------------------------
    // GHR — 4-bit Global History Register
    // ----------------------------------------------------------------
    logic [3:0] ghr;

    // ----------------------------------------------------------------
    // PHT — 16 entries of 2-bit saturating counters
    // 2'b11, 2'b10 = predict taken
    // 2'b01, 2'b00 = predict not-taken
    // ----------------------------------------------------------------
    logic [1:0] pht [0:15];

    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ghr <= 4'b0000;
            for (i = 0; i < 16; i++)
                pht[i] <= 2'b01; // weakly not-taken on reset
        end else if (update_en) begin
            // Update PHT entry indexed by current GHR
            if (actual_outcome) begin
                if (pht[ghr] != 2'b11)
                    pht[ghr] <= pht[ghr] + 1; // saturate at 11
            end else begin
                if (pht[ghr] != 2'b00)
                    pht[ghr] <= pht[ghr] - 1; // saturate at 00
            end
            // Shift GHR: push actual outcome into LSB
            ghr <= {ghr[2:0], actual_outcome};
        end
    end

    // Prediction: MSB of PHT entry = 1 means predict taken
    assign prediction = is_branch ? pht[ghr][1] : 1'b0;

endmodule
