
// APB slave: control/status registers for the matrix multiplier.
// 16-bit data, word-aligned register map, PREADY always 1 (no wait states).

// Offset  Name          Access      Contents
// 0x00    CTRL           W       [0] start (write 1 to launch a matmul; also clears the PE accumulators, done and the exception flag)
                                                                  
// 0x04    STATUS         R       [0] done, [1] any exception (flags[4:1], sticky), [2] busy
// 0x08    ADDR_A_TOP     R/W     address_mat_a_top
// 0x0C    ADDR_A_BOTTOM  R/W     address_mat_a_bottom
// 0x10    ADDR_B_LEFT    R/W     address_mat_b_left
// 0x14    ADDR_B_RIGHT   R/W     address_mat_b_right
// 0x18    ADDR_C_TOP     R/W     address_mat_c_top
// 0x1C    ADDR_C_BOTTOM  R/W     address_mat_c_bottom
// 0x20    STRIDE_A_TOP   R/W     address_stride_a_top
// 0x24    STRIDE_A_BOTTOM R/W     address_stride_a_bottom
// 0x28    STRIDE_B_LEFT  R/W     address_stride_b_left
// 0x2C    STRIDE_B_RIGHT R/W     address_stride_b_right
// 0x30    STRIDE_C_TOP   R/W     address_stride_c_top
// 0x34    STRIDE_C_BOTTOM R/W     address_stride_c_bottom
// 0x38    FLAGS           R       [4:0] {overflow, underflow, divide-by-zero, invalid, inexact} (sticky)


`define APB_ADDRWIDTH 8
`define APB_DATAWIDTH 16
`define REG_CTRL_ADDR     8'h00
`define REG_STATUS_ADDR   8'h04
`define REG_ADDR_A_TOP_ADDR 8'h08
`define REG_ADDR_A_BOTTOM_ADDR 8'h0C
`define REG_ADDR_B_LEFT_ADDR 8'h10
`define REG_ADDR_B_RIGHT_ADDR 8'h14
`define REG_ADDR_C_TOP_ADDR 8'h18
`define REG_ADDR_C_BOTTOM_ADDR 8'h1C
`define REG_STRIDE_A_TOP_ADDR 8'h20
`define REG_STRIDE_A_BOTTOM_ADDR 8'h24
`define REG_STRIDE_B_LEFT_ADDR 8'h28
`define REG_STRIDE_B_RIGHT_ADDR 8'h2C
`define REG_STRIDE_C_TOP_ADDR 8'h30
`define REG_STRIDE_C_BOTTOM_ADDR 8'h34
`define REG_FLAGS_ADDR 8'h38

module apb_slave #(

    parameter AW = 10, // matmul address width
    parameter SW = 8  // matmul stride width
    )
    (
    input logic                             PCLK,
    input logic                             PRESETn,
    input logic        [`APB_ADDRWIDTH-1:0] PADDR,
    input logic                             PWRITE,
    input logic                             PSEL,
    input logic                             PENABLE,
    input logic        [`APB_DATAWIDTH-1:0] PWDATA,
    output logic   [`APB_DATAWIDTH-1:0] PRDATA,
    output logic                        PREADY,
    output logic start,
    output logic pe_clear, // 1-cycle pulse: clears PE accumulators for a new run

	output logic [AW-1:0]                address_mat_a_top,
    output logic [AW-1:0]                address_mat_a_bottom,
    output logic [AW-1:0]                address_mat_b_left,
    output logic [AW-1:0]                address_mat_b_right,
    output logic [AW-1:0]                address_mat_c_top,
    output logic [AW-1:0]                address_mat_c_bottom,
    output logic [SW-1:0]                address_stride_a_top,
    output logic [SW-1:0]                address_stride_a_bottom,
    output logic [SW-1:0]                address_stride_b_left,
    output logic [SW-1:0]                address_stride_b_right,
    output logic [SW-1:0]                address_stride_c_top,
    output logic [SW-1:0]                address_stride_c_bottom,

    input logic done, // one-cycle pulse from matmul
	input logic [4:0] flags // exception flags from matmul
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

logic busy, done_r; // done and flags are sticky so the CPU can poll them after the pulse
logic [4:0] flags_r;

always_ff @(posedge PCLK) begin
        if (!PRESETn) begin
            start            <= 1'b0;
            pe_clear         <= 1'b0;
            done_r           <= 1'b0;
            flags_r          <= '0;
            busy             <= 1'b0;
            address_mat_a_top    <= '0;
            address_mat_a_bottom <= '0;
            address_mat_b_left   <= '0;
            address_mat_b_right  <= '0;
            address_mat_c_top    <= '0;
            address_mat_c_bottom <= '0;
            address_stride_a_top  <= '0;
            address_stride_a_bottom <= '0;
            address_stride_b_left <= '0;
            address_stride_b_right <= '0;
            address_stride_c_top  <= '0;
            address_stride_c_bottom <= '0;
        end else begin
            start <= 1'b0;
            pe_clear <= 1'b0;
 
            // Matmul side: done ends the run, flags are captured whenever raised
            if (done) begin
                busy  <= 1'b0;
                done_r <= 1'b1;
            end
            if (busy && !pe_clear) flags_r <= flags_r | flags;
 
            // CPU side: register writes (a start write clears old status)
            if (wr_en) begin
                case (PADDR)
                    `REG_CTRL_ADDR: begin                    
                        if (PWDATA[0] && !busy) begin
                                start    <= 1'b1;
                                pe_clear <= 1'b1;
                                busy     <= 1'b1;
                                done_r  <= 1'b0;
                                flags_r <= '0;
                        end
                    end
                    `REG_ADDR_A_TOP_ADDR:   address_mat_a_top    <= PWDATA[AW-1:0];
                    `REG_ADDR_A_BOTTOM_ADDR:   address_mat_a_bottom    <= PWDATA[AW-1:0];
                    `REG_ADDR_B_LEFT_ADDR:   address_mat_b_left    <= PWDATA[AW-1:0];
                    `REG_ADDR_B_RIGHT_ADDR:   address_mat_b_right    <= PWDATA[AW-1:0];
                    `REG_ADDR_C_TOP_ADDR:   address_mat_c_top    <= PWDATA[AW-1:0];
                    `REG_ADDR_C_BOTTOM_ADDR:   address_mat_c_bottom    <= PWDATA[AW-1:0];
                    `REG_STRIDE_A_TOP_ADDR: address_stride_a_top <= PWDATA[SW-1:0];
                    `REG_STRIDE_A_BOTTOM_ADDR: address_stride_a_bottom <= PWDATA[SW-1:0];
                    `REG_STRIDE_B_LEFT_ADDR: address_stride_b_left <= PWDATA[SW-1:0];
                    `REG_STRIDE_B_RIGHT_ADDR: address_stride_b_right <= PWDATA[SW-1:0];
                    `REG_STRIDE_C_TOP_ADDR: address_stride_c_top <= PWDATA[SW-1:0];
                    `REG_STRIDE_C_BOTTOM_ADDR: address_stride_c_bottom <= PWDATA[SW-1:0];
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
            `REG_STATUS_ADDR:   PRDATA <= {{(`APB_DATAWIDTH-3){1'b0}}, busy, |flags_r[4:1], done_r};
            `REG_ADDR_A_TOP_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_a_top);
            `REG_ADDR_A_BOTTOM_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_a_bottom);
            `REG_ADDR_B_LEFT_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_b_left);
            `REG_ADDR_B_RIGHT_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_b_right);
            `REG_ADDR_C_TOP_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_c_top);
            `REG_ADDR_C_BOTTOM_ADDR:   PRDATA <= `APB_DATAWIDTH'(address_mat_c_bottom);
            `REG_STRIDE_A_TOP_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_a_top);
            `REG_STRIDE_A_BOTTOM_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_a_bottom);
            `REG_STRIDE_B_LEFT_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_b_left);
            `REG_STRIDE_B_RIGHT_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_b_right);
            `REG_STRIDE_C_TOP_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_c_top);
            `REG_STRIDE_C_BOTTOM_ADDR: PRDATA <= `APB_DATAWIDTH'(address_stride_c_bottom);

            `REG_FLAGS_ADDR: PRDATA <= `APB_DATAWIDTH'(flags_r);
            default:            PRDATA <= '0;
        endcase
    end
end
 
endmodule
