`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module oversampled_reader #(
    parameter int oversampling_factor = 16
    )  (
    input  logic clk,
    input  logic rst_n,
    input  logic read,
    input  logic oversampling_tick,
    input  logic data_in,
    output logic data_ready,
    output logic data_out
    );
    

// Sampling Window Configuration
    localparam int fourth_part                      = oversampling_factor/4;                  // Calculating the numbers of readings
    localparam int reading_windows_size             = fourth_part - (fourth_part % 2) + 1;    // Ensuring that the number of reading is odd
    localparam int reading_windows_decisor_value    = fourth_part/2;                          // if <= data out = 0 else data out = 1
    
// Defining the imits of the reading windows
    localparam int middle_point             = oversampling_factor/2;
    localparam int inferior_reading_limit   = middle_point - (reading_windows_size-1)/2;
    localparam int superior_reading_limit   = middle_point + (reading_windows_size-1)/2;
    
// Counter widths
    localparam int internal_counter_bits    = $clog2(oversampling_factor + 1);
    localparam int reading_windows_bits     = $clog2(reading_windows_size + 1);

// Defining the maximum value of the counters
    localparam logic [(internal_counter_bits - 1) : 0] internal_counter_max     = internal_counter_bits'(oversampling_factor);
    localparam logic [(reading_windows_bits - 1)  : 0] reading_windows_max      = reading_windows_bits'(reading_windows_size);
    localparam logic [(internal_counter_bits - 1) : 0] reading_windows_init     = internal_counter_bits'(inferior_reading_limit);
    localparam logic [(internal_counter_bits - 1) : 0] reading_windows_end      = internal_counter_bits'(superior_reading_limit);
    localparam logic [(reading_windows_bits - 1)  : 0] reading_windows_decisor  = reading_windows_bits'(reading_windows_decisor_value);

// Internal signals
    logic [(internal_counter_bits - 1) : 0] internal_counter;
    logic [(reading_windows_bits - 1) : 0]  reading_windows_counter;


// Oversampling and majority voting
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            internal_counter        <= '0;
            reading_windows_counter <= '0;
            data_ready              <= '0;
            data_out                <= '1;
        end
        else begin
            if(!read) begin
                internal_counter        <= '0;
                reading_windows_counter <= '0;
                data_ready              <= '0;
                data_out                <= '1;
            end
            else begin
                data_ready <= '0;
                if(oversampling_tick) begin
                    internal_counter <= internal_counter + 1'b1;

                    if(internal_counter >= reading_windows_init && internal_counter <= reading_windows_end && data_in) begin
                        reading_windows_counter <= reading_windows_counter + 1'b1;
                    end

                    if(internal_counter >= (internal_counter_max - 1'b1)) begin
                        internal_counter        <= '0;
                        reading_windows_counter <= '0;
                        data_ready              <= '1;
                        if(reading_windows_counter > reading_windows_decisor) begin
                            data_out <= '1;
                        end
                        else begin
                            data_out <= '0;
                        end
                    end
                end
            end
        end
    end     
endmodule
