//========================================================================
// Sequential Machine Components: SRAMs
//========================================================================


module sm_mem_2rw_synch 
  #(
  parameter p_wid = 64, // word width
  parameter p_dep = 64, // number of words (rows)
  // local constants, not meant to be set from outside
  localparam lp_awid = $clog2(p_dep) // address width
  )
  (
  // control inputs
  input logic clkA,
  input logic clkB,
  input logic cenA, // port A chip enable (active low)
  input logic cenB, // port B chip enable (active low)
  input logic rwenA, // port A read/write enable (active low for write)
  input logic rwenB, // port B read/write enable (active low for write)
  // address inputs
  input logic [lp_awid-1:0] aA,
  input logic [lp_awid-1:0] aB,
  // data inputs
  input logic [p_wid-1:0] dA, // port A data input pins
  input logic [p_wid-1:0] dB, // port B data input pins
  // data outputs
  output logic [p_wid-1:0] qA,
  output logic [p_wid-1:0] qB
  );

  logic [p_wid-1:0] mem[p_dep-1:0];
  logic [p_wid-1:0] dA_l1, dA_l2, dB_l1, dB_l2;
  logic pipeline;

  assign pipeline = 0;

  always @(posedge clkA) begin
    // Read
    if (!cenA && rwenA) begin
      dA_l1 <= mem[aA];
    end
    dA_l2 <= dA_l1;
    // Write
    if (!cenA && !rwenA) begin
      mem[aA] <= dA;
    end
  end

  always @(posedge clkB) begin
    // Read
    if (!cenB && rwenB) begin
      dB_l1 <= mem[aB];
    end
    dB_l2 <= dB_l1;
    // Write
    if (!cenB && !rwenB) begin
      mem[aB] <= dB;
    end
  end

   // Generate Q output
   assign qA = pipeline ? dA_l2 : dA_l1;
   assign qB = pipeline ? dB_l2 : dB_l1;

   `ifndef SYNTHESIS
   always @(posedge clkA, posedge clkB) begin
    if (!cenA && rwenA && !cenB && !rwenB) begin
      assert (aA != aB)
        else $error("%m: ReadA/WriteB address collision");
    end
    if (!cenA && !rwenA && !cenB && rwenB) begin
      assert (aA != aB)
        else $error("%m: WriteA/ReadB address collision");
    end
   end
   `endif // SYNTHESIS
endmodule

// // BSG/bsg_ip_cores/bsg_mem/bsg_mem_2r1w.v
// // also in:
// // BSG/bsg_ip_cores/hard/bsg_mem/bsg_mem_2r1w.v
// // BSG/bsg_ip_cores/hard/tsmc_40/bsg_mem/bsg_mem_2r1w.v
// // MBT 4/1/2014
// //
// // 2 read-port, 1 write-port ram
// //
// // reads are asynchronous
// //

// //
// module bsg_mem_2r1w #(parameter width_p=-1
//                       , parameter els_p=-1
//                       , parameter read_write_same_addr_p=0
//                       , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
//                       )
//    (input   w_clk_i
//     , input w_reset_i

//     , input                     w_v_i
//     , input [addr_width_lp-1:0] w_addr_i
//     , input [width_p-1:0]       w_data_i

//     , input                      r0_v_i
//     , input [addr_width_lp-1:0]  r0_addr_i
//     , output logic [width_p-1:0] r0_data_o

//     , input                      r1_v_i
//     , input [addr_width_lp-1:0]  r1_addr_i
//     , output logic [width_p-1:0] r1_data_o

//     );

//    bsg_mem_2r1w_synth
//      #(.width_p(width_p)
//        ,.els_p(els_p)
//        ,.read_write_same_addr_p(read_write_same_addr_p)
//        ) synth
//        (.*);

// // synopsys translate_off

//    // always_ff @(posedge w_clk_i)
//    //   if (w_v_i)
//    //     begin
//    //        assert (w_addr_i < els_p)
//    //          else $error("Invalid address %x to %m of size %x\n", w_addr_i, els_p);

//    //        assert (~(r0_addr_i == w_addr_i && w_v_i && r0_v_i && !read_write_same_addr_p))
//    //          else $error("%m: Attempt to read and write same address");

//    //        assert (~(r1_addr_i == w_addr_i && w_v_i && r1_v_i && !read_write_same_addr_p))
//    //          else $error("%m: Attempt to read and write same address");
//    //     end

//    initial
//      begin
//         $display("## %L: instantiating width_p=%d, els_p=%d, read_write_same_addr_p=%d (%m)",width_p,els_p,read_write_same_addr_p);
//      end

// // synopsys translate_on

// endmodule

// // BSG/bsg_ip_cores/bsg_mem/bsg_mem_2r1w_synth.v
// // MBT 4/1/2014
// //
// // 2 read-port, 1 write-port ram
// //
// // reads are asynchronous
// //
// // this file should not be directly instantiated by end programmers
// // use bsg_mem_2r1w instead
// //

// module bsg_mem_2r1w_synth #(parameter width_p=-1
// 			    , parameter els_p=-1
// 			    , parameter read_write_same_addr_p=0
// 			    , parameter addr_width_lp=`BSG_SAFE_CLOG2(els_p)
// 			    )
//    (input   w_clk_i
//     , input w_reset_i

//     , input                     w_v_i
//     , input [addr_width_lp-1:0] w_addr_i
//     , input [width_p-1:0]       w_data_i

//     , input                      r0_v_i
//     , input [addr_width_lp-1:0]  r0_addr_i
//     , output logic [width_p-1:0] r0_data_o

//     , input                      r1_v_i
//     , input [addr_width_lp-1:0]  r1_addr_i
//     , output logic [width_p-1:0] r1_data_o

//     );

//    logic [width_p-1:0]    mem [els_p-1:0];

//    // this implementation ignores the r_v_i
//    assign r1_data_o = mem[r1_addr_i];
//    assign r0_data_o = mem[r0_addr_i];

//    wire                   unused = w_reset_i;

//    always_ff @(posedge w_clk_i)
//      if (w_v_i)
//        begin
//           mem[w_addr_i] <= w_data_i;
//        end

// endmodule
