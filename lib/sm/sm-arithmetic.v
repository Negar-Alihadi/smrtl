//========================================================================
// Verilog Components: Arithmetic Components
//========================================================================

`ifndef SM_ARITHMETIC_V
`define SM_ARITHMETIC_V

//------------------------------------------------------------------------
// Multipliers
//------------------------------------------------------------------------

module sm_SimpleMultiplier
#(
  parameter p_nbits = 16
)(
  input  [p_nbits-1 : 0] in0,
  input  [p_nbits-1 : 0] in1,
  output [p_nbits-1 : 0] out
);

  wire [2*p_nbits-1:0] product;
  
  Error_Configurable_Multiplier
  #(
    .p_nbits(p_nbits)
  ) 
  multiplier_inst (
    .A(in0),
    .B(in1),
    .Er(3'b000), 
    .P(product)
  );
  
  assign out = product[p_nbits-1 : 0];  // Take lower bits

endmodule

// Alternative version with error input
module sm_ErrorConfigurableMultiplier
#(
  parameter p_nbits = 16
)(
  input  [p_nbits-1 : 0] in0,
  input  [p_nbits-1 : 0] in1,
  input  [2 : 0]         error_config,  
  output [p_nbits-1 : 0] out
);

  wire [2*p_nbits-1 : 0] product;
  
  Error_Configurable_Multiplier
  #(
    .p_nbits(p_nbits)
  ) 
  multiplier_inst (
    .A(in0),
    .B(in1),
    .Er(error_config),
    .P(product)
  );
  
  assign out = product[p_nbits-1 : 0];

endmodule

// Parameterized Error Configurable Multiplier

module Error_Configurable_Multiplier
#(
  parameter p_nbits = 16
)(
    input   wire    [p_nbits-1 : 0]    A, 
    input   wire    [p_nbits-1 : 0]    B, 
    input   wire    [2 : 0]            Er,
    output  wire    [2*p_nbits-1 : 0]  P
);
    // Calculate number of partial products and intermediate sizes
    localparam NUM_PP = p_nbits;
    localparam IPP_SIZE = p_nbits + 3;  // p_nbits + shift amount (0-2)
    localparam FINAL_SIZE = 2 * p_nbits;
    
    // Primary Partial Products
    wire [p_nbits-1:0] PP [1:NUM_PP];

    generate
        for (genvar i = 1; i <= NUM_PP; i = i + 1)
        begin : Array_Generate_Block
            assign PP[i] = {p_nbits{B[i - 1]}} & A;
        end
    endgenerate
    
    // For different sizes, we need different compression tree structures
    generate
        if (p_nbits == 8) begin : mult_8bit
            // 8-bit multiplier
            wire [10:0] IPP [1:4];
            wire [2:0] inter_carry;
            
            Compressor_4_2
            #(
                .N(11),
                .APX_Part(11)
            )    
            compressor_4_2_11_bit_1
            (
                .X_1    (   {3'b0, PP[1]}           ),
                .X_2    (   {2'b0, PP[2], 1'b0}     ),
                .X_3    (   {1'b0, PP[3], 2'b0}     ),
                .X_4    (   {PP[4], 3'b0}           ),
                .Cin    (   1'b0                    ),
                .Er     (   Er[0]                   ),
                
                .Sum    (   IPP[1]                  ),
                .Carry  (   IPP[2]                  ),
                .Cout   (   inter_carry[0]          )
            );
            
            Compressor_4_2
            #(
                .N(11),
                .APX_Part(11)
            )  
            compressor_4_2_11_bit_2
            (
                .X_1    (   {3'b0, PP[5]}           ),
                .X_2    (   {2'b0, PP[6], 1'b0}     ),
                .X_3    (   {1'b0, PP[7], 2'b0}     ),
                .X_4    (   {PP[8], 3'b0}           ),
                .Cin    (   inter_carry[0]          ),
                .Er     (   Er[1]                   ),
                
                .Sum    (   IPP[3]                  ),
                .Carry  (   IPP[4]                  ),
                .Cout   (   inter_carry[1]          )
            );

            // Final Partial Product
            wire [15:0] FPP [1:2];

            Compressor_4_2
            #(
                .N(16),
                .APX_Part(16)
            ) 
            compressor_4_2_16_bit
            (
                .X_1    (   {5'b0, IPP[1]}          ),
                .X_2    (   {4'b0, IPP[2], 1'b0}    ),
                .X_3    (   {1'b0, IPP[3], 4'b0}    ),
                .X_4    (   {IPP[4], 5'b0}          ),
                .Cin    (   inter_carry[1]          ),
                .Er     (   Er[2]                   ),
                
                .Sum    (   FPP[1]                  ),
                .Carry  (   FPP[2]                  ),
                .Cout   (   inter_carry[2]          )
            );

            // Final Addition 
            wire [16:0] product_temp;

            Ripple_Carry_Adder
            #(
                .N(17)
            )
            ripple_carry_adder
            (
                .A      (   {1'b0, FPP[1]}  ),
                .B      (   {FPP[2], 1'b0}  ),
                .Cin    (   inter_carry[2]  ),
                
                .Cout   (                   ),
                .Sum    (   product_temp    )
            );

            assign P = product_temp[15:0];
        end
        else if (p_nbits == 16) begin : mult_16bit
            // 16-bit multiplier
            wire [18:0] IPP1 [1:8];
            wire [3:0] inter_carry1;
            
            // First level of 4:2 compressors (4 compressors)
            for (genvar i = 0; i < 4; i = i + 1)
            begin : First_Level_Compressors
                Compressor_4_2
                #(
                    .N(19),
                    .APX_Part(19)
                )    
                compressor_4_2_19_bit
                (
                    .X_1    (   {3'b0, PP[i*4 + 1]}           ),
                    .X_2    (   {2'b0, PP[i*4 + 2], 1'b0}     ),
                    .X_3    (   {1'b0, PP[i*4 + 3], 2'b0}     ),
                    .X_4    (   {PP[i*4 + 4], 3'b0}           ),
                    .Cin    (   (i == 0) ? 1'b0 : inter_carry1[i-1] ),
                    .Er     (   Er[0]                         ),
                    
                    .Sum    (   IPP1[i*2 + 1]                 ),
                    .Carry  (   IPP1[i*2 + 2]                 ),
                    .Cout   (   inter_carry1[i]               )
                );
            end

            // Second level of compression
            wire [21:0] IPP2 [1:4];
            wire [1:0] inter_carry2;
            
            Compressor_4_2
            #(
                .N(22),
                .APX_Part(22)
            )  
            compressor_4_2_22_bit_1
            (
                .X_1    (   {3'b0, IPP1[1]}           ),
                .X_2    (   {2'b0, IPP1[2], 1'b0}     ),
                .X_3    (   {1'b0, IPP1[3], 2'b0}     ),
                .X_4    (   {IPP1[4], 3'b0}           ),
                .Cin    (   1'b0                      ),
                .Er     (   Er[1]                     ),
                
                .Sum    (   IPP2[1]                   ),
                .Carry  (   IPP2[2]                   ),
                .Cout   (   inter_carry2[0]           )
            );
            
            Compressor_4_2
            #(
                .N(22),
                .APX_Part(22)
            )  
            compressor_4_2_22_bit_2
            (
                .X_1    (   {3'b0, IPP1[5]}           ),
                .X_2    (   {2'b0, IPP1[6], 1'b0}     ),
                .X_3    (   {1'b0, IPP1[7], 2'b0}     ),
                .X_4    (   {IPP1[8], 3'b0}           ),
                .Cin    (   inter_carry2[0]           ),
                .Er     (   Er[1]                     ),
                
                .Sum    (   IPP2[3]                   ),
                .Carry  (   IPP2[4]                   ),
                .Cout   (   inter_carry2[1]           )
            );

            // Final Partial Product
            wire [31:0] FPP [1:2];

            Compressor_4_2
            #(
                .N(32),
                .APX_Part(32)
            ) 
            compressor_4_2_32_bit
            (
                .X_1    (   {10'b0, IPP2[1]}           ),
                .X_2    (   {9'b0, IPP2[2], 1'b0}      ),
                .X_3    (   {1'b0, IPP2[3], 9'b0}      ),
                .X_4    (   {IPP2[4], 10'b0}           ),
                .Cin    (   inter_carry2[1]            ),
                .Er     (   Er[2]                      ),
                
                .Sum    (   FPP[1]                     ),
                .Carry  (   FPP[2]                     ),
                .Cout   (   /* Open */                 )
            );

            // Final Addition 
            wire [32:0] product_temp;

            Ripple_Carry_Adder
            #(
                .N(33)
            )
            ripple_carry_adder
            (
                .A      (   {1'b0, FPP[1]}  ),
                .B      (   {FPP[2], 1'b0}  ),
                .Cin    (   1'b0            ),
                
                .Cout   (                   ),
                .Sum    (   product_temp    )
            );

            assign P = product_temp[31:0];
        end
        else if (p_nbits == 32) begin : mult_32bit
          
            wire [2*p_nbits-1:0] product_temp;
            assign product_temp = A * B;  
            assign P = product_temp;
        end
        else begin : mult_other
            wire [2*p_nbits-1:0] product_temp;
            assign product_temp = A * B;
            assign P = product_temp;
        end
    endgenerate
endmodule

module Compressor_4_2
#
(
    parameter N = 16,
    parameter APX_Part = 2
)
(
    input   wire    [N - 1 : 0]     X_1,
    input   wire    [N - 1 : 0]     X_2,
    input   wire    [N - 1 : 0]     X_3,
    input   wire    [N - 1 : 0]     X_4,
    input   wire                    Cin,
    input   wire                    Er,
    
    output  wire    [N - 1 : 0]     Sum,
    output  wire    [N - 1 : 0]     Carry,
    output  wire                    Cout
);
    wire [N - 1 : 0] temp_sum;
    wire [N : 0] carry_chain;
    assign carry_chain[0] = Cin;

    genvar i;
    generate
        for (i = 0; i < APX_Part; i = i + 1) 
        begin : Approximate_Compression
            AFA_A AFA_A_1
            (
                .A      (   X_1[i]  ),
                .B      (   X_2[i]  ),
                .Cin    (   X_3[i]  ),
                .Er     (   Er      ),

                .Cout   (   carry_chain[i + 1]  ),
                .Sum    (   temp_sum[i]         )
            );

            AFA_A AFA_A_2
            (
                .A      (   X_4[i]          ),
                .B      (   temp_sum[i]     ),
                .Cin    (   carry_chain[i]  ),
                .Er     (   Er              ),
                
                .Cout   (   Carry[i]  ),
                .Sum    (   Sum[i]    )
            );
        end
    endgenerate
    
    /*generate
        for (i = APX_Part; i < N ; i = i + 1) 
        begin : Exact_Compression
            Full_Adder FA_1
            (
                .A      (   X_1[i]  ),
                .B      (   X_2[i]  ),
                .Cin    (   X_3[i]  ),

                .Cout   (   carry_chain[i + 1]  ),
                .Sum    (   temp_sum[i]         )
            );

            Full_Adder FA_2
            (
                .A      (   X_4[i]          ),
                .B      (   temp_sum[i]     ),
                .Cin    (   carry_chain[i]  ),

                .Cout   (   Carry[i]  ),
                .Sum    (   Sum[i]    )
            );
        end
    endgenerate*/

    assign Cout = carry_chain[N];
endmodule

module Ripple_Carry_Adder 
#(
    parameter N = 16
) 
(   
    input   wire    [N - 1 : 0]     A,
    input   wire    [N - 1 : 0]     B,
    input   wire                    Cin,

    output  wire    [N - 1 : 0]     Sum,     
    output  wire                    Cout       
);

    wire [N : 0] carry_chain;         
    assign carry_chain[0] = Cin;

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) 
        begin : Full_Adder_Chain
            Full_Adder FA 
            (
                .A(A[i]),
                .B(B[i]),
                .Cin(carry_chain[i]),
                .Sum(Sum[i]),
                .Cout(carry_chain[i + 1])
            );
        end
    endgenerate

    assign Cout = carry_chain[N];
endmodule

module Full_Adder 
(
    input   wire    A,
    input   wire    B,
    input   wire    Cin,

    output  wire    Sum,
    output  wire    Cout
);
    assign Sum = A ^ B ^ Cin;
    assign Cout = (A & B) || (A & Cin) || (B & Cin);
endmodule

module Half_Adder 
(
    input   wire    A,
    input   wire    B, 

    output  wire    Sum, 
    output  wire    Cout
);
    assign Sum = A ^ B;
    assign Cout = A & B;
endmodule

module AFA_A(
    input   A,
    input   B,
    input   Cin,
    input   Er,
    output  Sum,
    output  Cout
);

    assign Sum = (Cin && ~Er) || (A ^ B ^ Cin);
    assign Cout = (A && B) || (Cin && Er && (A || B));
endmodule

//------------------------------------------------------------------------
// 8-bit SubWord Sampler (SWS)
//------------------------------------------------------------------------
// …,5,4,3,2,1,0
module sm_SubWordSampler8
#(
  parameter p_nbits = 16,
  parameter p_startbits = 16
)(
  input  [p_nbits-1:0] in,
  input  [p_startbits-1:0] startbit,
  output [p_nbits-1:0] out
);

  assign out = ( in >> startbit[15:0] );

endmodule

//------------------------------------------------------------------------
// ReLU
//------------------------------------------------------------------------

module sm_ReLu
#(
  parameter p_nbits = 16
)(
  input  [p_nbits-1:0] in,
  output [p_nbits-1:0] out
);

  assign out = (in[p_nbits-1]==0)? in : 0; // pass positive, zero-out negative

endmodule

`endif /* SM_ARITHMETIC_V */

