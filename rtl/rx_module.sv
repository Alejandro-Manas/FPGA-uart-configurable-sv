`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/22/2026 05:41:43 PM
// Design Name: 
// Module Name: rx_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rx_module #(
    parameter int clk_freq = 200_000_000,
    parameter int oversampling_factor = 16
    )   (
    input  logic            clk,
    input  logic            rst_n,
    input  logic            data_in_rx,
    input  logic [2 : 0]    baud_rate,
    input  logic [1 : 0]    parity_bit,         // 00 <- NONE   01 <- EVEN  10 <- ODD 

    output logic            byte_ready,
    output logic            byte_valid,
    output logic [7 : 0]    byte_out
    );

    logic data_in_aux;
    logic data_in;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            data_in_aux <= '1;
            data_in     <= '1;
        end
        else begin
            data_in_aux <= data_in_rx;
            data_in     <= data_in_aux;
        end
    end


    logic clear_baud_generator;

    baud_gen #(
        .clk_freq               (clk_freq),
        .oversampling_factor    (oversampling_factor)
    ) baud_generator (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .clear                  (clear_baud_generator),
        .baud_rate              (baud_rate),
        .oversampling_tick      (oversampling_tick)
    );

    logic oversampling_tick;

    logic read_oversampler;
    logic data_ready_oversampler;
    logic data_out_oversampler;

    oversampled_reader #(
        .oversampling_factor    (oversampling_factor)
    ) oversampler (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .read                   (read_oversampler),
        .oversampling_tick      (oversampling_tick),
        .data_in                (data_in),
        .data_ready             (data_ready_oversampler),
        .data_out               (data_out_oversampler)
    );

    logic [7 : 0] received_byte;
    logic [2 : 0] bits_counter;

    typedef enum logic [2 : 0] {
        IDLE        =   3'b000, 
        START_BIT   =   3'b001,
        READ_BYTE   =   3'b010,
        PARITY_BIT  =   3'b011,
        STOP_BIT    =   3'b100
    } rx_state_t;
    rx_state_t rx_state;


    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rx_state                <= IDLE;
            byte_out                <= '0;
            byte_ready              <= '0;
            byte_valid              <= '0;
            received_byte           <= '0;
            bits_counter            <= '0;
            clear_baud_generator    <= '1;
            read_oversampler        <= '0;
        end
        else begin
            case(rx_state)
                IDLE        : begin
                rx_state                <= IDLE;
                //byte_out                <= '0;
                byte_ready              <= '0;
                byte_valid              <= '0;
                received_byte           <= '0;
                bits_counter            <= '0;
                clear_baud_generator    <= '1;
                read_oversampler        <= '0;
                if(!data_in) begin
                    rx_state    <= START_BIT;
                    clear_baud_generator    <= '0;
                    read_oversampler        <= '1;
                end
                end

                START_BIT   : begin
                    rx_state                <= START_BIT;
                    clear_baud_generator    <= '0;
                    read_oversampler        <= '1;
                    if(data_ready_oversampler) begin
                        if(data_out_oversampler) begin
                            clear_baud_generator    <= '1;
                            read_oversampler        <= '0; 
                            rx_state                <= IDLE;                         
                        end
                        else begin
                            rx_state                <= READ_BYTE;
                        end
                    end 
                end

                READ_BYTE   : begin 
                    rx_state                <= READ_BYTE;
                    clear_baud_generator    <= '0;
                    read_oversampler        <= '1;
                    if(data_ready_oversampler) begin
                        received_byte       <= {data_out_oversampler, received_byte[7:1]};
                        bits_counter        <= bits_counter + 1'b1;
                        if(bits_counter == 3'b111) begin
                            bits_counter    <= '0;
                            if(parity_bit != 2'b00) begin
                                rx_state    <= PARITY_BIT;
                            end
                            else begin
                                rx_state    <= STOP_BIT;
                                byte_valid  <= '1;  
                            end
                        end
                    end     
                end

                PARITY_BIT  : begin
                    rx_state                <= PARITY_BIT;
                    clear_baud_generator    <= '0;
                    read_oversampler        <= '1;
                    if(data_ready_oversampler) begin
                        rx_state            <= STOP_BIT;     
                        case(parity_bit)
                            2'b00   : byte_valid  <= '1;
                            2'b01   : byte_valid  <= (data_out_oversampler == ^received_byte);
                            2'b10   : byte_valid  <= (data_out_oversampler == ~(^received_byte));
                            default : byte_valid  <= '0;
                        endcase
                    end
                end

                STOP_BIT  : begin
                    rx_state                <= STOP_BIT;
                    clear_baud_generator    <= '0;
                    read_oversampler        <= '1;

                    if(data_ready_oversampler) begin
                        clear_baud_generator <= '1;
                        read_oversampler    <= '0; 
                        rx_state            <= IDLE;
                        byte_ready          <= '1;
                        byte_out            <= received_byte;
                        if(!data_out_oversampler) begin
                            byte_valid      <= '0;
                        end
                    end
                end

                default   : rx_state <= IDLE;
            endcase
        end
    end

endmodule
