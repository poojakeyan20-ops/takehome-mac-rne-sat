`timescale 1ns/1ps
//
// mac_rne_sat -- implement per doc/spec.md.
// Do not change the module name, port list, or port directions.
// Synthesizable SystemVerilog only (Icarus Verilog, -g2012). No SVA.
//
module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,       // synchronous, active-high
    input  logic               en,        // accumulate a*b this cycle
    input  logic               clr,       // clear accumulator this cycle
    input  logic               rd,        // request readout snapshot this cycle
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,       // rounded + saturated snapshot
    output logic               res_valid, // 1-cycle pulse, one cycle after rd
    output logic               ovf        // sticky saturation flag
);

    // TODO: implement the accumulate / readout / overflow logic per
    // doc/spec.md. The tie-offs below only keep the skeleton compiling;
    // replace them with your implementation.
   
    // -------------------------------------------------------------------------
    // 1. Internal Register Definitions
    // -------------------------------------------------------------------------
    logic signed [27:0] acc;
    logic               rd_d;        // Delayed rd signal for res_valid pulse

    // Intermediate combinational signals for processing the readout path
    logic signed [27:0] snapshot;
    logic signed [19:0] q;         // floor(snapshot / 256) -> snapshot >>> 8
    logic        [7:0]  r;         // Remainder: snapshot [7:0]
    logic signed [20:0] rounded;   // Rounded value before saturation
    
    logic signed [15:0] res_next;
    logic signed [15:0] product;
    logic               sat_occurred;

    // -------------------------------------------------------------------------
    // 2. Readout Path (Combinational)
    // -------------------------------------------------------------------------
    // Snapshot is taken BEFORE any acc updates in the current clock cycle.
    assign snapshot = acc;

    // In two's complement, right shifting arithmetic (>>>) gives floor(snapshot / 256).
    // The lower 8 bits directly yield the positive remainder r in [0, 255].
    assign q = snapshot >>> 8;
    assign r = snapshot[7:0];

    // Round-Half-to-Even (RNE) Logic at 8 LSBs
    always_comb begin
        if (r < 8'd128) begin
            rounded = q;
        end else if (r > 8'd128) begin
            rounded = q + 1'b1;
        end else begin // r == 128 (Exact tie)
            if (q[0] == 1'b1) begin
                rounded = q + 1'b1; // Odd q rounds up to even
            end else begin
                rounded = q;        // Even q stays even
            end
        end
    end

    // Saturation Logic: Clamping to [-32768, +32767]
    always_comb begin
        if (rounded > 21'sd32767) begin
            res_next     = 16'sd32767;
            sat_occurred = 1'b1;
        end else if (rounded < -21'sd32768) begin
            res_next     = -16'sd32768;
            sat_occurred = 1'b1;
        end else begin
            res_next     = rounded[15:0];
            sat_occurred = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // 3. Sequential Logic & Accumulator Update
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            acc       <= 28'sd0;
            res       <= 16'sd0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;
            rd_d      <= 1'b0;
        end else begin
            // --- Accumulator Control ---
            case ({clr, en})
                2'b01: acc <= acc + $signed(a * b); // Accumulate
                2'b10: acc <= 28'sd0;               // Clear
                2'b11: acc <= $signed(a * b);       // Clear-then-accumulate
                default: acc <= acc;               // Hold
            endcase

            // --- Readout Result & Valid Flag ---
            rd_d      <= 1'b0;
            res_valid <= rd_d;
            if (rd_d) 
                res <= res_next;

            // --- Sticky Overflow Flag Logic ---
            // Set wins over clr if a saturating readout occurs in the same cycle.
            if (rd_d && sat_occurred)            // Saturation always sets
               ovf <= 1'b1;
            else if (clr)                       // Clear only when no saturation
               ovf <= 1'b0;
            
        end
    end

endmodule
