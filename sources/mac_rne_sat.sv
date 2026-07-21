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

    //----------------------------------------------------------------------
    // Internal Registers
    //----------------------------------------------------------------------

    // 28-bit signed accumulator
    logic signed [27:0] acc;

    // Stores accumulator snapshot when rd is asserted
    logic signed [27:0] snapshot;

    // Delays rd by one clock
    logic rd_pipe;

    // Product registers
    logic signed [15:0] product16;
    logic signed [27:0] product28;

    // Variables used during rounding
    logic signed [27:0] q;
    logic [7:0]         r;
    logic signed [28:0] rounded;

    //----------------------------------------------------------------------
    // Combinational multiplication
    //----------------------------------------------------------------------

    always_comb begin

        // 8-bit × 8-bit multiplication
        product16 = a * b;

        // Sign extend to 28 bits before accumulation
        product28 = {{12{product16[15]}}, product16};

    end

    //----------------------------------------------------------------------
    // Sequential logic
    //----------------------------------------------------------------------

    always_ff @(posedge clk) begin

        //--------------------------------------------------------------
        // RESET
        //--------------------------------------------------------------

        if (rst) begin

            acc       <= 28'sd0;
            snapshot  <= 28'sd0;

            rd_pipe   <= 1'b0;

            res       <= 16'sd0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;

        end
        else begin

            //----------------------------------------------------------
            // STEP 1
            // Capture snapshot BEFORE accumulator changes.
            //
            // This satisfies:
            //
            // "Snapshot is accumulator value at end of previous cycle."
            //----------------------------------------------------------

            rd_pipe <= rd;

            if (rd)
                snapshot <= acc;

            //----------------------------------------------------------
            // STEP 2
            // Update accumulator
            //----------------------------------------------------------

            if (clr) begin

                // Clear has priority

                if (en)

                    // Clear then accumulate
                    acc <= product28;

                else

                    // Only clear
                    acc <= 28'sd0;

            end

            else if (en) begin

                // Normal accumulate
                acc <= acc + product28;

            end

            //----------------------------------------------------------
            // STEP 3
            // Generate res_valid
            //
            // Exactly one cycle after rd.
            //----------------------------------------------------------

            res_valid <= rd_pipe;

            //----------------------------------------------------------
            // STEP 4
            // Perform read operation
            //----------------------------------------------------------

            if (rd_pipe) begin

                //------------------------------------------------------
                // Divide by 256
                //------------------------------------------------------

                q = snapshot >>> 8;

                //------------------------------------------------------
                // Calculate remainder
                //
                // remainder = snapshot - q*256
                //------------------------------------------------------

                r = snapshot - (q <<< 8);

                //------------------------------------------------------
                // Default rounded value
                //------------------------------------------------------

                rounded = q;

                //------------------------------------------------------
                // Round-half-to-even
                //------------------------------------------------------

                if (r > 8'd128)

                    rounded = q + 1;

                else if (r == 8'd128) begin

                    // Tie case

                    if (q[0])

                        // Odd quotient -> round up

                        rounded = q + 1;

                    // Even quotient
                    // Do nothing

                end

                //------------------------------------------------------
                // Saturation
                //------------------------------------------------------

                if (rounded > 32767) begin

                    res <= 16'sd32767;

                    ovf <= 1'b1;

                end

                else if (rounded < -32768) begin

                    res <= -16'sd32768;

                    ovf <= 1'b1;

                end

                else begin

                    // No saturation

                    res <= rounded[15:0];

                    // Clear ovf only when clr occurs
                    if (clr)
                        ovf <= 1'b0;

                end

            end

            //----------------------------------------------------------
            // No read this cycle
            //----------------------------------------------------------

            else begin

                // Clear sticky overflow only on clr

                if (clr)
                    ovf <= 1'b0;

            end

        end

    end

endmodule 


