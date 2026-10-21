
// APB slave: control/status registers for the matrix multiplier.
// 16-bit data, word-aligned register map, PREADY always 1 (no wait states).

// Offset  Name       Access  Contents
// 0x00    CTRL       W       [0] start (write 1 to launch a matmul; also clears 
                                                                  // the PE accumulators, done and the exception flag)
// 0x04    STATUS     R       [0] done, [1] exception flag (sticky)
// 0x08    ADDR_A     R/W     address_mat_a
// 0x0C    ADDR_B     R/W     address_mat_b
// 0x10    ADDR_C     R/W     address_mat_c
// 0x14    STRIDE_A   R/W     address_stride_a
// 0x18    STRIDE_B   R/W     address_stride_b
// 0x1C    STRIDE_C   R/W     address_stride_c


`define REG_ADDRWIDTH 8
`define REG_DATAWIDTH 16
`define REG_CTRL_ADDR     8'h00
`define REG_STATUS_ADDR   8'h04
`define REG_ADDR_A_ADDR   8'h08
`define REG_ADDR_B_ADDR   8'h0C
`define REG_ADDR_C_ADDR   8'h10
`define REG_STRIDE_A_ADDR 8'h14
`define REG_STRIDE_B_ADDR 8'h18
`define REG_STRIDE_C_ADDR 8'h1C

module apb_slave #(

    parameter AW = 10,   // matmul address width
    parameter SW = 8     // matmul stride width
    )
    (
    input logic                             PCLK,
    input logic                             PRESETn,
    input logic        [`REG_ADDRWIDTH-1:0] PADDR,
    input logic                             PWRITE,
    input logic                             PSEL,
    input logic                             PENABLE,
    input logic        [`REG_DATAWIDTH-1:0] PWDATA,
    output logic   [`REG_DATAWIDTH-1:0] PRDATA,
    output logic                        PREADY,
    output logic start,
    output logic pe_clear, // 1-cycle pulse: clears PE accumulators for a new run

	output logic [AW-1:0]                address_mat_a,
    output logic [AW-1:0]                address_mat_b,
    output logic [AW-1:0]                address_mat_c,
    output logic [SW-1:0]                address_stride_a,
    output logic [SW-1:0]                address_stride_b,
    output logic [SW-1:0]                address_stride_c,
    input logic done, // one-cycle pulse from matmul
	input logic flags // exception flag from matmul
);

//Recommend using ENUMs
reg [1:0] State;
//States will be IDLE, SETUP, READ_ACCESS and WRITE_ACCESS

always @(posedge PCLK) begin
  if (PRESETn == 0) begin
    State <= `IDLE;
    .....
  end

  else begin
    case (State)
       ....
	   
      `WRITE_ACCESS : begin
        if (PWRITE && PENABLE) begin
          case (PADDR)
          `REG_STRT_ADDR  : begin
                                start <= PWDATA[0];                   
                            end
          
          .....
          endcase
          
        end
        
      end

      `READ_ACCESS : begin
        if (!PWRITE && PENABLE) begin
          
          case (PADDR)
          `REG_DONE_ADDR  : PRDATA <= {done, 15'b0};
          
          ....
          endcase
        end
        
      end
      ....
     
    endcase
  end
end 

endmodule
