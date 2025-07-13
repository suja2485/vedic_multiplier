//-----------------------------------------------------------------------------
//
// File name    :  design.sv
// Title        :  VEDIC 8x8 MULTIPLIER DESIGN
//
// ----------------------------------------------------------------------------
// Revision History :
// ----------------------------------------------------------------------------
//   Ver  :| Author         :| Mod. Date   :| Changes Made:
//   v1.0  | J Sujatha      :| 2025/05/23  :|
// ----------------------------------------------------------------------------
//
// ============================================================================
//  EXPLANATION AND ARCHITECTURE
// ----------------------------------------------------------------------------
// This module implements an 8-bit by 8-bit multiplier using the principles of
// Vedic mathematics, specifically the "Urdhva Tiryagbhyam" sutra (Sanskrit for
// "vertically and crosswise"). This method enables parallel generation of
// partial products and significantly improves speed compared to traditional
// shift-and-add algorithms.
//
// -----------------------------
// ARCHITECTURE BREAKDOWN:
// -----------------------------
//
// 1. Top Module: vedic8x8
//    - Inputs: 8-bit operands a and b
//    - Output: 16-bit product
//    - Instantiates four 4x4 Vedic multipliers:
//      * VD0: LSBs of a and b (a[3:0], b[3:0])
//      * VD1: LSBs of a and MSBs of b (a[3:0], b[7:4])
//      * VD2: MSBs of a and LSBs of b (a[7:4], b[3:0])
//      * VD3: MSBs of a and b (a[7:4], b[7:4])
//    - Combines partial products using ripple carry adders:
//      * RA0: Adds shifted outputs of VD0 and VD2
//      * RA1: Adds shifted outputs of VD1 and VD3
//      * RA2: Adds results from RA0 and RA1
//
// 2. Submodule: vedic4x4
//    - Inputs: 4-bit operands
//    - Output: 8-bit product
//    - Built using four vedic2x2 blocks, following a similar pattern
//    - Uses 4-bit and 6-bit ripple adders to sum intermediate products
//
// 3. Submodule: vedic2x2
//    - Inputs: 2-bit operands
//    - Output: 4-bit product
//    - Computes partial products using bitwise ANDs
//    - Uses half adders to combine overlapping terms
//
// 4. Adders:
//    - ripple_adder_4bit/6bit/8bit/12bit: Custom-built ripple-carry adder modules
//    - full_adder and half_adder modules build the adder hierarchy
//
// -----------------------------
// DESIGN ADVANTAGES:
// -----------------------------
// - Parallel Generation: All partial products are calculated in parallel.
// - Hierarchical: Each higher-level multiplier reuses smaller ones, making the
//   design modular and reusable.
// - Area-Speed Trade-off: Offers better performance than shift-and-add and can
//   be area-efficient for moderate bit widths (ideal for FPGAs).
// - Synthesizable: All components are written in synthesizable Verilog.
//
// -----------------------------
// EXTENSION SUGGESTIONS:
// -----------------------------
// - Parametrize bit-width for N x N multiplication
// - Introduce pipelining between adder stages to improve throughput
// - Replace ripple adders with faster adder types (e.g., carry-lookahead)
// - Implement signed multiplication support
//
// ============================================================================
//`default_nettype none
`timescale 1ns/10ps

module vedic8x8(
  input  [7:0]  a, b,
  output [15:0] prod);

  wire   [7:0]  mult0, mult1, mult2, mult3;
  wire   [7:0]  sum0;
  wire   [11:0] sum1, sum2;
  wire carry1, carry2, carry3;

  vedic4x4 VD0(.a(a[3:0]),
               .b(b[3:0]),
               .prod(mult0));
  
  vedic4x4 VD1(.a(a[3:0]),
               .b(b[7:4]),
               .prod(mult1));
  
  vedic4x4 VD2(.a(a[7:4]),
               .b(b[3:0]),
               .prod(mult2));
  
  vedic4x4 VD3(.a(a[7:4]),
               .b(b[7:4]),
               .prod(mult3));

  ripple_adder_8bit RA0(.a({4'b0,mult0[7:4]}),
                        .b(mult2),
                        .cin(1'b0),
                        .sum(sum0),
                        .cout(carry1));
  
  ripple_adder_12bit RA1(.a({4'b0,mult1}),
                         .b({mult3,4'b0}),
                         .cin(1'b0),
                         .sum(sum1),
                         .cout(carry2));
  
  ripple_adder_12bit RA2(.a({4'b0,sum0}),
                          .b(sum1),
                          .cin(1'b0),
                          .sum(sum2),
                          .cout(carry3));

  assign prod = {sum2, mult0[3:0]};
endmodule

module vedic4x4(
  input  [3:0] a, b,
  output [7:0] prod);

  wire   [3:0] mult0, mult1, mult2, mult3;
  wire   [3:0] sum0;
  wire   [5:0] sum1, sum2;
  wire carry1, carry2, carry3;

  vedic2x2 VD0(.a(a[1:0]),
               .b(b[1:0]),
               .prod(mult0));
  
  vedic2x2 VD1(.a(a[1:0]),
               .b(b[3:2]),
               .prod(mult1));
  
  vedic2x2 VD2(.a(a[3:2]),
               .b(b[1:0]),
               .prod(mult2));
  
  vedic2x2 VD3(.a(a[3:2]),
               .b(b[3:2]),
               .prod(mult3));

  ripple_adder_4bit RA0(.a({2'b0, mult0[3:2]}),
                        .b(mult2),
                        .cin(1'b0),
                        .sum(sum0),
                        .cout(carry1));
  
  ripple_adder_6bit RA1(.a({2'b0, mult1}),
                        .b({mult3, 2'b0}),
                        .cin(1'b0),
                        .sum(sum1),
                        .cout(carry2));
  
  ripple_adder_6bit RA2(.a({2'b0, sum0}),
                        .b(sum1),
                        .cin(1'b0),
                        .sum(sum2),
                        .cout(carry3));
	
  assign prod = {sum2, mult0[1:0]};
endmodule

module vedic2x2(
  input  [1:0] a, b,
  output [3:0] prod);

  wire a1b1 = a[1] & b[1];
  wire a0b1 = a[0] & b[1];
  wire a1b0 = a[1] & b[0];
  wire a0b0 = a[0] & b[0];
  wire carry;

  assign prod[0] = a0b0;

  half_adder HA0(.a(a0b1),
                 .b(a1b0),
                 .sum(prod[1]),
                 .cout(carry));
  
  half_adder HA1(.a(a1b1),
                 .b(carry),
                 .sum(prod[2]),
                 .cout(prod[3]));
endmodule

module ripple_adder_12bit(
  input  [11:0] a, b,
  input         cin,
  output [11:0] sum,
  output        cout);

  wire carry;

  ripple_adder_6bit RA0(.a(a[5:0]),
                        .b(b[5:0]),
                        .cin(cin),
                        .sum(sum[5:0]),
                        .cout(carry));
  
  ripple_adder_6bit RA1(.a(a[11:6]),
                        .b(b[11:6]),
                        .cin(carry),
                        .sum(sum[11:6]),
                        .cout(cout));
endmodule

module ripple_adder_8bit(
  input  [7:0] a, b,
  input        cin,
  output [7:0] sum,
  output       cout);

  wire carry;

  ripple_adder_4bit RA0(.a(a[3:0]),
                        .b(b[3:0]),
                        .cin(cin),
                        .sum(sum[3:0]),
                        .cout(carry));
  
  ripple_adder_4bit RA1(.a(a[7:4]),
                        .b(b[7:4]),
                        .cin(carry),
                        .sum(sum[7:4]),
                        .cout(cout));
endmodule

module ripple_adder_6bit(
  input  [5:0] a, b,
  input        cin,
  output [5:0] sum,
  output       cout);

  wire carry1, carry2, carry3, carry4, carry5;

  full_adder FA0(.a(a[0]),
                 .b(b[0]),
                 .cin(cin),
                 .sum(sum[0]),
                 .cout(carry1));
  
  full_adder FA1(.a(a[1]),
                 .b(b[1]),
                 .cin(carry1),
                 .sum(sum[1]),
                 .cout(carry2));
  
  full_adder FA2(.a(a[2]),
                 .b(b[2]),
                 .cin(carry2),
                 .sum(sum[2]),
                 .cout(carry3));
  
  full_adder FA3(.a(a[3]),
                 .b(b[3]),
                 .cin(carry3),
                 .sum(sum[3]),
                 .cout(carry4));
  
  full_adder FA4(.a(a[4]),
                 .b(b[4]),
                 .cin(carry4),
                 .sum(sum[4]),
                 .cout(carry5));
  
  full_adder FA5(.a(a[5]),
                 .b(b[5]),
                 .cin(carry5),
                 .sum(sum[5]),
                 .cout(cout));
endmodule

module ripple_adder_4bit(
  input  [3:0] a, b,
  input        cin,
  output [3:0] sum,
  output       cout);

  wire carry1, carry2, carry3;
  
  full_adder FA0(.a(a[0]),
                 .b(b[0]),
                 .cin(cin),
                 .sum(sum[0]),
                 .cout(carry1));
  
  full_adder FA1(.a(a[1]),
                 .b(b[1]),
                 .cin(carry1),
                 .sum(sum[1]),
                 .cout(carry2));
  
  full_adder FA2(.a(a[2]),
                 .b(b[2]),
                 .cin(carry2),
                 .sum(sum[2]),
                 .cout(carry3));
  
  full_adder FA3(.a(a[3]),
                 .b(b[3]),
                 .cin(carry3),
                 .sum(sum[3]),
                 .cout(cout));
endmodule

module full_adder(
  input  a, b, cin,
  output sum, cout);
  
  wire sum1, carry1, carry2;
  
  half_adder HA0(.a(a),
                 .b(b),
                 .sum(sum1),
                 .cout(carry1));
  
  half_adder HA1(.a(cin),
                 .b(sum1),
                 .sum(sum),
                 .cout(carry2));

  assign cout = carry1 | carry2;
endmodule

module half_adder(
  input  a, b,
  output sum, cout);

  assign sum = a ^ b;
  assign cout = a & b;
endmodule