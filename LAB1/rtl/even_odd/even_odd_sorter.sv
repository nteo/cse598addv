// Top Module: Even Odd Sorter
module even_odd_sorter #(
    parameter int FIFO_DEPTH = 6,
    parameter int DATA_WIDTH = 8
)
    (
    input   logic                    clk,
    input   logic                    rst_n,
    input   logic [DATA_WIDTH-1:0]   data_in,
    input   logic                    write_en,
    output  logic [DATA_WIDTH-1:0]   data_out,
    input   logic                    read_en
);
    
    // Interface instantiatons
    fifo_if even_fifo_i();
    fifo_if odd_fifo_i();

    // Module instantiations
    input_sorter #(.DATA_WIDTH(DATA_WIDTH)) input_sorter_inst (.*);
    fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(FIFO_DEPTH)) even_fifo (.fifo_i(even_fifo_i));
    fifo #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(FIFO_DEPTH)) odd_fifo (.fifo_i(odd_fifo_i));
    output_selector #(.DATA_WIDTH(DATA_WIDTH)) output_selector_inst (.*);

    // Assign the input clock to the read and write clocks for both fifo's
    assign even_fifo_i.wclk = clk;
    assign even_fifo_i.rclk = clk;
    assign odd_fifo_i.wclk = clk;
    assign odd_fifo_i.rclk = clk;

    // Assign the reset to the read and write resets for both fifo's
    assign even_fifo_i.wrst_n = rst_n;
    assign even_fifo_i.rrst_n = rst_n;
    assign odd_fifo_i.wrst_n = rst_n;
    assign odd_fifo_i.rrst_n = rst_n;

endmodule


// Input Sorter
// Takes in a number and writes it into either the even fifo or odd fifo
module input_sorter #(
    parameter int DATA_WIDTH = 8
)
    (
    fifo_if.CONTROLLER even_fifo_i,
    fifo_if.CONTROLLER odd_fifo_i,
    input   logic [DATA_WIDTH-1:0]  data_in,
    input   logic                   write_en
);
    // Internal signals
    logic even_odd_flag;    // determines if data_in is even (0) or odd (1)

    // Evaluate if data_in is even or odd
    assign even_odd_flag = data_in[0];

    always_comb begin
        // If writing is disabled,
        if (!write_en) begin
            // Disable both fifo's write inputs
            even_fifo_i.wdata = 'x;
            odd_fifo_i.wdata = 'x;
            even_fifo_i.winc = 0;
            odd_fifo_i.winc = 0;
        end
        // If the flag is 1 (odd)
        else if (even_odd_flag) begin
            // Configure the odd fifo's inputs to write data_in
            odd_fifo_i.wdata = data_in;
            odd_fifo_i.winc = 1;

            // Configure the even fifo's inputs to not write anything
            even_fifo_i.wdata = 'x;
            even_fifo_i.winc = 0;
        end

        // If the flag is 0 (even)
        else begin
            // Configure the even fifo's inputs to write data_in
            even_fifo_i.wdata = data_in;
            even_fifo_i.winc = 1;

            // Configure the odd fifo's inputs to not write anything
            odd_fifo_i.wdata = 'x;
            odd_fifo_i.winc = 0;
        end
    end
endmodule

// Define the state enumerator
typedef enum logic {EVEN, ODD} state_e; // determines if an even or odd number is currently outputted

// Output Selector
// Reads from the even fifo and odd fifo and alternates between reading from both
module output_selector #(
    parameter int DATA_WIDTH = 8
)
    (
    fifo_if.CONTROLLER even_fifo_i,
    fifo_if.CONTROLLER odd_fifo_i,
    input   logic                   clk,
    input   logic                   rst_n,
    input   logic                   read_en,
    output  logic [DATA_WIDTH-1:0]  data_out
    );

    // Internal signals
    state_e current_state, next_state;
    logic [DATA_WIDTH-1:0] next_data_out;

    // Update the current state
    always_ff @(posedge clk or negedge rst_n) begin
        // If a reset is asserted,
        if (!rst_n) begin
            // Reset the current state to even
            current_state <= EVEN;

            // Reset the output
            data_out <= 'x;
        end

        // Otherwise, if read is enabled, set the current state to the next state
        else if (read_en) begin
            current_state <= next_state;
            data_out <= next_data_out;
        end

        // Otherwise, keep the current state and output as is
        else begin
            current_state <= current_state;
            data_out <= data_out;
        end
    end

    // Determine the next state
    always_comb begin
        // If read is not enabled, keep the next state as the current state
        if (!read_en) begin
            next_state = current_state;
        end
        
        // Otherwise, check whether the selector is looking for an even or odd number
        else begin
            case (current_state)
                EVEN: begin
                    // If the odd fifo is not empty, set the next state to ODD
                    if (!odd_fifo_i.empty) begin
                        next_state = ODD;
                    end

                    // Otherwise, keep the next state as EVEN
                    else begin
                        next_state = EVEN;
                    end
                end

                ODD: begin
                    // If the odd fifo is not empty, set the next state to EVEN
                    if (!even_fifo_i.empty) begin
                        next_state = EVEN;
                    end

                    // Otherwise, keep the next state as ODD
                    else begin
                        next_state = ODD;
                    end
                end

                default: begin
                    next_state = EVEN;
                end
            endcase
        end
    end

    // Determine the read enable for even and odd
    always_comb begin
        // If read is not enabled, keep the read enables off
        if (!read_en) begin
            even_fifo_i.rinc = 0;
            odd_fifo_i.rinc = 0;
        end
        
        // Otherwise, check if the current output is an even or odd number
        else begin
            case (current_state)
                EVEN: begin
                    // If the current output is even, enable the read for the odd fifo
                    even_fifo_i.rinc = 0;

                    // If the odd fifo is not empty, enable the read for the odd fifo
                    if (!odd_fifo_i.empty) begin
                        odd_fifo_i.rinc = 1;
                    end
                    
                    // Otherwise, disable the read for the even fifo
                    else begin
                        odd_fifo_i.rinc = 0;
                    end
                end

                ODD: begin
                    // If the current output is odd, enable the read for the even fifo
                    odd_fifo_i.rinc = 0;

                    // If the even fifo is not empty, enable the read for the even fifo
                    if (!even_fifo_i.empty) begin
                        even_fifo_i.rinc = 1;
                    end

                    // Otherwise, disable the read for the even fifo
                    else begin
                        even_fifo_i.rinc = 0;
                    end
                end

                default: begin
                    odd_fifo_i.rinc = 0;
                    even_fifo_i.rinc = 0;
                end
            endcase
        end
    end

    // Determine the next output of the selector
    always_comb begin
        // If read is not enabled, keep the next output as the current output
        if (!read_en) begin
            next_data_out = data_out;
        end
        
        // Otherwise, check if the current output is an even or odd number
        else begin
            case (current_state)
                EVEN: begin
                    // If the current output is even, output the next odd number

                    // If the odd fifo is not empty, set the next output
                    if (!odd_fifo_i.empty) begin
                        next_data_out = odd_fifo_i.rdata;
                    end
                    
                    // Otherwise, do not update the output
                    else begin
                        next_data_out = data_out;
                    end
                end

                ODD: begin
                    // If the current output is odd, output the next even number

                    // If the even fifo is not empty, set the next output
                    if (!even_fifo_i.empty) begin
                        next_data_out = even_fifo_i.rdata;
                    end

                    // Otherwise, do not update the output
                    else begin
                        next_data_out = data_out;
                    end
                end

                default: begin
                    next_data_out = data_out;
                end
            endcase
        end
    end
endmodule