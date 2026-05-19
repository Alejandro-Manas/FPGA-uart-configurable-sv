`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas    
//////////////////////////////////////////////////////////////////////////////////

module tx_module #(
    parameter int clk_freq = 200_000_000,
    parameter int oversampling_factor = 16
    )   (
    input  logic            clk,
    input  logic            rst_n,
    input  logic            send,
    input  logic [7 : 0]    byte_in,
    input  logic [2 : 0]    baud_rate,
    input  logic [1 : 0]    parity_bit_mode,

    output logic            data_out,
    output logic            available_to_send
    );

// Internal signals
    logic [7:0] byte_to_send;
    logic       clear_baud_generator;
    logic       oversampling_tick;


// Submodule instantiation
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


// Timing and counter parameters
    localparam int bits_oversampler_counter = $clog2(oversampling_factor + 1);
    localparam logic [(bits_oversampler_counter - 1) : 0] oversampler_counter_max   =   bits_oversampler_counter'(oversampling_factor);
    localparam logic [2 : 0]                              bit_counter_max           =   3'b111;

    logic [(bits_oversampler_counter - 1) : 0]  oversampler_counter;
    logic [2 : 0]                               bit_counter;
    logic                                       parity_bit_value;


// TX FSM
    typedef enum logic [2 : 0] {  
        IDLE        = 3'b000,
        START_BIT   = 3'b001,
        BYTE_SEND   = 3'b010,
        PARITY_BIT  = 3'b011,
        STOP_BIT    = 3'b100
    } tx_state_t;
    tx_state_t tx_state;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_state                <= IDLE;
            data_out                <= '1;
            clear_baud_generator    <= '1;
            oversampler_counter     <= '0;
            byte_to_send            <= '0;
            parity_bit_value        <= '1;
            available_to_send       <= '1;
            bit_counter             <= '0;
        end
        else begin
            available_to_send       <= '0;
            case(tx_state)
                IDLE        :   begin
                    tx_state                    <= IDLE;
                    data_out                    <= '1;
                    clear_baud_generator        <= '1;
                    oversampler_counter         <= '0;
                    byte_to_send                <= '0;
                    parity_bit_value            <= '1;
                    available_to_send           <= '1;

                    if(send) begin
                        tx_state                <= START_BIT;
                        data_out                <= '0;
                        clear_baud_generator    <= '0;
                        available_to_send       <= '0;
                        byte_to_send            <= byte_in;

                        //Calculation of the parity bit to no have to save the vaule of the byte so we are able to do a right shift
                        if(parity_bit_mode != 2'b00) begin 
                            case(parity_bit_mode)
                                2'b01   :   parity_bit_value    <=  ^byte_in;
                                2'b10   :   parity_bit_value    <=  ~(^byte_in);
                                default :   parity_bit_value    <=  '1;
                            endcase
                        end
                    end
                end

                START_BIT   :   begin
                    tx_state            <= START_BIT;
                    data_out            <= '0;

                    if(oversampling_tick) begin
                        oversampler_counter     <= oversampler_counter + 1'b1;
                        if(oversampler_counter  >= (oversampler_counter_max - 1'b1)) begin 
                            oversampler_counter <= '0;
                            tx_state            <= BYTE_SEND;
                            bit_counter         <= '0;
                            data_out            <= byte_to_send[0];
                        end     
                    end
                end

                BYTE_SEND   :   begin
                    tx_state                    <=  BYTE_SEND;
                    data_out                    <=  byte_to_send[0];

                    if(oversampling_tick) begin
                        oversampler_counter     <=  oversampler_counter + 1'b1;
                        if(oversampler_counter  >=  (oversampler_counter_max - 1'b1)) begin 
                            oversampler_counter <=  '0;
                            bit_counter         <=  bit_counter + 1'b1;
                            data_out                    <=  byte_to_send[1];
                            byte_to_send        <=  {1'b1, byte_to_send[7:1]};
                            if(bit_counter == bit_counter_max) begin   
                                if(parity_bit_mode != 2'b00) begin
                                    tx_state    <= PARITY_BIT;
                                    data_out    <= parity_bit_value;
                                    bit_counter <= '0;
                                end
                                else begin
                                    tx_state    <= STOP_BIT;
                                    data_out    <= '1;    
                                end
                            end
                        end 
                    end

                    
                end

                PARITY_BIT  :   begin
                    tx_state                    <=  PARITY_BIT;
                    data_out                    <=  parity_bit_value;
                    if(oversampling_tick) begin
                        oversampler_counter <= oversampler_counter + 1'b1;
                        if(oversampler_counter >= (oversampler_counter_max - 1'b1)) begin
                            tx_state            <= STOP_BIT;
                            data_out            <= '1;
                            oversampler_counter <= '0;
                        end
                    end
                end

                STOP_BIT    :   begin
                    tx_state                    <=  STOP_BIT;
                    data_out                    <=  '1;
                    if(oversampling_tick) begin
                        oversampler_counter <= oversampler_counter + 1'b1;
                        if(oversampler_counter >= (oversampler_counter_max - 1'b1)) begin
                            tx_state            <= IDLE;
                            data_out            <= '1;
                            oversampler_counter <= '0;
                            available_to_send   <= '1;
                        end
                    end
                end

                default     :   tx_state        <= IDLE;
            endcase 
        end
    end

endmodule