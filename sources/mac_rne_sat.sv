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
   
    // 28-bit accumulator
    logic signed [27:0] acc;

    // Pipeline registers for read request
    logic               rd_d;
    logic signed [27:0] snapshot_d;

    // Product
    logic signed [15:0] prod16;
    logic signed [27:0] prod28;

    // Intermediate variables
    logic signed [27:0] q;
    logic [7:0] r;
    logic signed [28:0] rounded;
    logic sat;

    always_comb begin
        prod16 = a * b;
        prod28 = {{12{prod16[15]}}, prod16};

        // Defaults
        q       = snapshot_d >>> 8;      // arithmetic divide by 256
        r       = snapshot_d[7:0];       // remainder 0..255
        rounded = q;
        sat     = 1'b0;

        // Round-half-to-even
        if (r > 8'd128)
            rounded = q + 1;
        else if (r == 8'd128) begin
            if (q[0])
                rounded = q + 1;
        end

        // Saturation detection
        if (rounded > 32767) begin
            sat = 1'b1;
        end
        else if (rounded < -32768) begin
            sat = 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            acc        <= 28'sd0;
            snapshot_d <= 28'sd0;
            rd_d       <= 1'b0;
            res        <= 16'sd0;
            res_valid  <= 1'b0;
            ovf        <= 1'b0;
        end
        else begin
            // Pipeline read request
            rd_d <= rd;
            if (rd)
                snapshot_d <= acc;

            // res_valid pulse
            res_valid <= rd_d;

            // Produce read result
            if (rd_d) begin
                if (rounded > 32767)
                    res <= 16'sd32767;
                else if (rounded < -32768)
                    res <= -16'sd32768;
                else
                    res <= rounded[15:0];
            end

            // Sticky overflow flag
            if (rd_d && sat)
                ovf <= 1'b1;
            else if (clr)
                ovf <= 1'b0;

            // Accumulator update
            if (clr) begin
                if (en)
                    acc <= prod28;
                else
                    acc <= 28'sd0;
            end
            else if (en) begin
                acc <= acc + prod28;
            end
        end
    end

endmodule
