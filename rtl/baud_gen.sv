`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module baud_gen #(
        parameter int clk_freq = 200_000_000,
        parameter int oversampling_factor = 16
    ) (
        input  logic clk,
        input  logic rst_n,
        input  logic clear,
        input  logic [2:0] baud_rate,       // 0=9600, 1=19200, 2=38400, 3=57600, 4=115200
        output logic oversampling_tick
    );


// Baud rate divisors calculated at compile time

    localparam int B9600   = clk_freq / (9600   * oversampling_factor);
    localparam int B19200  = clk_freq / (19200  * oversampling_factor);
    localparam int B38400  = clk_freq / (38400  * oversampling_factor);
    localparam int B57600  = clk_freq / (57600  * oversampling_factor);
    localparam int B115200 = clk_freq / (115200 * oversampling_factor);


// Largest divisor used for counter width
    localparam int max_counter_value    = B9600;
    localparam int max_counter_bits     = $clog2(max_counter_value + 1);

    logic [(max_counter_bits - 1) : 0] counter;
    logic [(max_counter_bits - 1) : 0] counter_max;


// Baud rate mux selector
    always_comb begin
        case (baud_rate)
            3'b000  : counter_max = max_counter_bits'(B9600);
            3'b001  : counter_max = max_counter_bits'(B19200);
            3'b010  : counter_max = max_counter_bits'(B38400);
            3'b011  : counter_max = max_counter_bits'(B57600);
            3'b100  : counter_max = max_counter_bits'(B115200);
            default : counter_max = max_counter_bits'(B9600);
        endcase
    end

// Counter and tick generation
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            counter <= '0;
            oversampling_tick <= '0;
        end
        else if (clear) begin 
            counter <= '0;
            oversampling_tick <= '0;
        end
        else begin
            counter <= counter + 1'b1;
            oversampling_tick <= '0;
            if(counter >= (counter_max - 1'b1)) begin
                counter <= '0;
                oversampling_tick <= '1;
            end
        end 
    end

endmodule
