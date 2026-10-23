
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

    parameter AW = 10, // matmul address width
    parameter SW = 8  // matmul stride width
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

assign PREADY = 1'b1; // No wait states: every transfer completes in its access phase

typedef enum logic [1:0] {IDLE, SETUP, READ_ACCESS, WRITE_ACCESS} state_t;
state_t State;


// SETUP: setup phase was seen, the access phase (PENABLE=1) executes the transfer
logic wr_en, rd_en;
assign wr_en = (State == SETUP) & PSEL & PENABLE &  PWRITE;
assign rd_en = (State == SETUP) & PSEL & PENABLE & ~PWRITE;



always_ff @(posedge PCLK) begin
    if (!PRESETn)
        State <= IDLE;
    else begin
        case (State)
            IDLE:   
                if (PSEL && !PENABLE)
                State <= SETUP;

            SETUP:
                if (PSEL && PENABLE)
                    State <= PWRITE ? WRITE_ACCESS : READ_ACCESS;

            READ_ACCESS, WRITE_ACCESS: 
                State <= (PSEL && !PENABLE) ? SETUP : IDLE;

            default: State <= IDLE;
        endcase
    end
end

logic done_r, flags_r; // done and flags are sticky so the CPU can poll them after the pulse

always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            start            <= 1'b0;
            pe_clear         <= 1'b0;
            done_r           <= 1'b0;
            flags_r          <= 1'b0;
            address_mat_a    <= '0;
            address_mat_b    <= '0;
            address_mat_c    <= '0;
            address_stride_a <= '0;
            address_stride_b <= '0;
            address_stride_c <= '0;
        end else begin
            pe_clear <= 1'b0;
 
            // Matmul side: done ends the run, flags are captured whenever raised
            if (done) begin
                start  <= 1'b0;
                done_r <= 1'b1;
            end
            if (flags) flags_r <= 1'b1;
 
            // CPU side: register writes (a start write clears old status)
            if (wr_en) begin
                case (PADDR)
                    `REG_CTRL_ADDR: begin
                        start <= PWDATA[0];
                        if (PWDATA[0]) begin
                            pe_clear <= 1'b1;
                            done_r  <= 1'b0;
                            flags_r <= 1'b0;
                        end
                    end
                    `REG_ADDR_A_ADDR:   address_mat_a    <= PWDATA[AW-1:0];
                    `REG_ADDR_B_ADDR:   address_mat_b    <= PWDATA[AW-1:0];
                    `REG_ADDR_C_ADDR:   address_mat_c    <= PWDATA[AW-1:0];
                    `REG_STRIDE_A_ADDR: address_stride_a <= PWDATA[SW-1:0];
                    `REG_STRIDE_B_ADDR: address_stride_b <= PWDATA[SW-1:0];
                    `REG_STRIDE_C_ADDR: address_stride_c <= PWDATA[SW-1:0];
                    default: ;
                endcase
            end
        end
    end
 
    // Register reads: PRDATA is registered and valid after the access phase
always_ff @(posedge PCLK) begin
    if (!PRESETn)
        PRDATA <= '0;
    else if (rd_en) begin
        case (PADDR)
            `REG_STATUS_ADDR:   PRDATA <= {{(`APB_DATAWIDTH-2){1'b0}}, flags_r, done_r};
            `REG_ADDR_A_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_a);
            `REG_ADDR_B_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_b);
            `REG_ADDR_C_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_c);
            `REG_STRIDE_A_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_a);
            `REG_STRIDE_B_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_b);
            `REG_STRIDE_C_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_c);

            default:            PRDATA <= '0;
        endcase
    end
end
 
endmodule
