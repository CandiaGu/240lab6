/*
 * File: p18240.v
 * Created: 11/13/1997
 * Modules contained: p18240_top
 * 
 * Changelog:
 * 9 June 1999 : Added stack pointer
 * 4/16/2001: Reverted to base code. (verBurg)
 * 4/16/2001: Added the "addsp" instruction. (verBurg)
 * 11/26/06: Removed old Altera-specific code that Xilinx tool had trouble with (P. Milder)
 * 3 Oc 2009: Cleaned up coding style and changed module name (mcbender)
 * 13 Oct 2009: Removed tabs and fixed spacing, added negedge trigger (mcbender)
 * 18 Oct 2009: Changed some constant names (mcbender)
 * 23 Oct 2009: Added LEDController (mcbender)
 * 31 Oct 2009: Fixed wire and instance naming style (mcbender)
 * 4 Nov 2009: Modified spacing slightly (mcbender)
 * 17 Nov 2009: Minor modification to facilitate synthesis (mcbender)
 * 13 Oct 2010: Updated always to always_comb and always_ff.Renamed to.sv(abeera) 
 * 17 Oct 2010: Updated to use enums instead of define's (iclanton)
 * 24 Oct 2010: Updated to use stuct (abeera)
 * 9  Nov 2010: Slightly modified variable names.
 *               Updated display to use enum (abeera)
 * 17 Apr 2013: Added timeout to simulation, such that simulation stops after 50000 cycles (wnace)
 * 25 Apr 2013: Commented synthesis by default,
 *              changed always_ff to always to remove VCS errors on cycle var (mromanko)
 * 15 Apr 2014: The `define synthesis is now in constants.sv
 * 14 Nov 2014: Memory removed from datapath and instantiated as its own module (wnace)
 * 
 * 
 * This is the baseline code that should be used at the beginning of
 * every semester.  It is finally all unified and brought up to date
 * (minus coding style differences).
*/

`include "constants.sv"
`default_nettype none

/*
 * module p18240_top
 *
 * This is the top-level module for our implementation of the p18240 ISA.
 * 
 */
module p18240_top( 
  output logic  [6:0] HEX7, HEX6, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0,
  output logic  [8:0] LEDG,
  output logic [17:0] LEDR,
  input  logic  [3:0] KEY,
  input  logic [17:0] SW);
    
   
  controlPts cPts;               // control points
  logic [3:0]  condCodes;                // condition codes (Z,C,N,V)
  logic [2:0]  regSelA, regSelB;         // destination, source
  logic [15:0] aluSrc1, aluSrc2, aluOut, pc, ir, sp, memAddr, memData;
  logic [127:0] regView;
  logic [15:0] r7, r6, r5, r4, r3, r2, r1, r0;
  opcode_t currState, nextState;
  wire [15:0] dataBus;
  
  logic clock, reset_L;

  logic [1:0] winAddSub;
   
//on the board, we'll use pushbuttons for clock and reset
`ifdef synthesis
   assign clock   = KEY[0];
   assign reset_L = KEY[1];
//in simulation, we'll generate them this way
`else
   initial begin
      reset_L = 1;
      #2;
      reset_L = 0;
      #2;
      reset_L = 1;
   end
   initial begin              //posedge of the clock occurs on multiples of #10
      clock = 1;
      forever #5 clock = ~clock;
   end
`endif
   
   controlpath cp(
                 .out(cPts),
                 .CCin(condCodes),
                 .IRIn(ir),
                 .clock(clock),
                 .reset_L(reset_L),
                 .currState(currState),
                 .nextState(nextState)
		 .winAddSub(winAddSub);
   
   datapath dp(
              .ir(ir),
              .sp(sp),
              .condCodes(condCodes),
              .aluSrcA(aluSrc1),
              .aluSrcB(aluSrc2),
              .viewReg(regView),
              .aluResult(aluOut),
              .pc(pc),
              .memAddr(memAddr),
              .MDRout(memData),
              .dataBus(dataBus),
              .regSelA(regSelA),
              .regSelB(regSelB),
              .cPts(cPts),
              .clock(clock),
              .reset_L(reset_L)
	      .winAddSub(winAddSub));

   memorySystem mem(
                   .data(dataBus), 
                   .address(memAddr), 
                   .re_L(cPts.re_L), 
                   .we_L(cPts.we_L), 
                   .clock(clock));
   
//output display on the board for synthesis
  logic [15:0] disp1, disp0;
  
  assign {r7, r6, r5, r4, r3, r2, r1, r0} = regView;
  
  always_comb begin
    disp1 = 16'h0000; disp0 = 16'h0000;
    case ({SW[17], SW[16]})
      2'b00: begin
               disp1 = pc;
               disp0 = ir;
             end
      2'b01: begin
               disp1 = memAddr;
               disp0 = memData;
             end
      2'b10: begin
               disp1 = r3;
               disp0 = r2;
             end
      2'b11: begin
               disp1 = r1;
               disp0 = r0;
             end
    endcase
  end
  
  SevenSegmentControl ssc(
                         .HEX7(HEX7), 
                         .HEX6(HEX6), 
                         .HEX5(HEX5), 
                         .HEX4(HEX4),
                         .HEX3(HEX3), 
                         .HEX2(HEX2), 
                         .HEX1(HEX1), 
                         .HEX0(HEX0),
                         .in7(disp1[15:12]), 
                         .in6(disp1[11:8] ), 
                         .in5(disp1[7:4]), 
                         .in4(disp1[3:0] ), 
                         .in3(disp0[15:12]), 
                         .in2(disp0[11:8] ), 
                         .in1(disp0[7:4]), 
                         .in0(disp0[3:0] ),
                         .turn_on(8'hFF));
                         
  assign LEDR[17] = ~cPts.re_L;
  assign LEDR[16] = ~cPts.we_L;


//output display for simulation
`ifdef synthesis
`else
   integer cycle;

   initial cycle = 0;

   always @ (negedge clock) begin
      $display("cycle %d", cycle);
      $display("R0: 0x%x  R1: 0x%x  R2: 0x%x  R3: 0x%x", 
           r0, r1, r2, r3);
      $display("R4: 0x%x  R5: 0x%x  R6: 0x%x  R7: 0x%x", 
           r4, r5, r6, r7);
      $display("CState: %s  NState: %s", currState, nextState);
      $display("Dest: %s LoadCC: %s REI: %s WEI: %s",
           cPts.dest, cPts.lcc_L, cPts.re_L, cPts.we_L);
      $display("ALUop: %s     SrcA: %s      SrcB: %s",
           cPts.alu_op, cPts.srcA, cPts.srcB);
      $display("AddrA: %h        AddrB: %h", regSelA, regSelB);
      $display("ALUInA: 0x%h  ALUInB: 0x%h  ALUOut: 0x%h",  
           aluSrc1, aluSrc2, aluOut);
      $display("PC:     0x%h  IR:     0x%h  SP:     0x%h", pc, ir, sp);
      $display("MAR:    0x%h  MDR     0x%h  ZCNV:   %b", memAddr, memData, condCodes);
      $display("==================================================");
      cycle = cycle + 1;
      if (cycle > 50000)
        $stop;
   end
`endif

endmodule

