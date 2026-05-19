`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module tx_sim(

    );

    localparam oversampling_factor  = 16;
    localparam clk_freq             = 200000000.0;

    localparam clk_period           = 1000000000.0/clk_freq;
    localparam clk_semiperiod       = clk_period / 2.0;

    logic           clk;
    logic           rst_n;
    logic           send;
    logic [7:0]     byte_in;
    logic [2:0]     baud_rate;
    logic [1:0]     parity_bit_mode;

    logic           data_out;
    logic           available_to_send;

    tx_module #(
        .oversampling_factor    (oversampling_factor),
        .clk_freq               (clk_freq)
    ) uut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .send                   (send),
        .byte_in                (byte_in),
        .baud_rate              (baud_rate),
        .parity_bit_mode        (parity_bit_mode),

        .data_out               (data_out),
        .available_to_send      (available_to_send)
    );

    always begin
        clk = 0; #(clk_semiperiod);
        clk = 1; #(clk_semiperiod);
    end

    task send_byte(
        logic [7:0] byte_in_sim,
        logic [2:0] baud_rate_sim,
        logic [1:0] parity_bit_mode_sim
    );
    begin
        logic [7:0] real_byte_sended;

        byte_in         = byte_in_sim;
        baud_rate       = baud_rate_sim;
        parity_bit_mode = parity_bit_mode_sim;

        send = '0;

        @(negedge clk);
        #(clk_period);

        $display("[%0t] StARTING SEQUENCE: Byte in: %b. Baud rate: %b, Parity bit mode: %b", $time, byte_in_sim, baud_rate_sim, parity_bit_mode_sim);


        //Initializing Idle state
        if(uut.tx_state != uut.IDLE) begin
            $display("[%0t] Initial state is not IDLE, restarting state module.", $time);
            rst_n = '0;
            #(clk_period);
            rst_n = '1;
            #(5*clk_period);
            $display("[%0t] Initial state: IDLE.", $time);
        end
        else begin 
            $display("[%0t] Initial state: IDLE.", $time);
        end


        //Test Start Bit
        send = '1;
        #(4*clk_period);
        send = '0;
        assert(uut.tx_state == uut.START_BIT)
            $display("[%0t] ASSERT PASSED: Start Bit, state correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Expected state: Start Bit. Current State %s", $time, uut.tx_state.name());

        assert(uut.available_to_send == 1'b0)
            $display("[%0t] ASSERT PASSED: Available to send correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Available to send incorrect, it should be inactive. %s", $time, uut.tx_state.name());

        for(int i = 0; i < oversampling_factor; i ++) begin
            @(negedge uut.oversampling_tick);
        end
        

        //Test Send Byte
        assert(uut.tx_state == uut.BYTE_SEND)
            $display("[%0t] ASSERT PASSED: Byte Send, state correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Expected state: Byte Send. Current State %s", $time, uut.tx_state.name());

        for(int i = 0; i < 8; i ++) begin
            real_byte_sended[i] = data_out;
            for(int j = 0; j < oversampling_factor; j ++) begin
                @(negedge uut.oversampling_tick);
            end
        end
        assert(real_byte_sended == byte_in_sim)
            $display("[%0t] ASSERT PASSED: Byte Send correctly", $time);
        else
            $error("[%0t] ASSERT FAILED: Byte not sended correctly. Expected byte: %b. Real byte: %b", $time, byte_in_sim, real_byte_sended);


        //Test Parity Bit
        if(parity_bit_mode != 2'b00) begin
            assert(uut.tx_state == uut.PARITY_BIT)
                $display("[%0t] ASSERT PASSED: Parity Bit, state correct", $time);
            else
                $error("[%0t] ASSERT FAILED: Expected state: Parity Bit. Current State %s", $time, uut.tx_state.name());  
             
            case(parity_bit_mode)
                2'b01   :   begin
                    assert(data_out == ^real_byte_sended)
                        $display("[%0t] ASSERT PASSED: Parity Bit correct.", $time);
                    else
                        $error("[%0t] ASSERT FAILED: Parity Bit incorrect. Expected: %b. Real: %b", $time, (^real_byte_sended), data_out);
                end
                2'b10   :   begin
                    assert(data_out == ~(^real_byte_sended))
                        $display("[%0t] ASSERT PASSED: Parity Bit correct.", $time);
                    else
                        $error("[%0t] ASSERT FAILED: Parity Bit incorrect. Expected: %b. Real: %b", $time, (~(^real_byte_sended)), data_out);
                end
                default :   begin
                    assert(data_out == 1'b1)
                        $display("[%0t] ASSERT PASSED: Parity Bit correct.", $time);
                    else
                        $error("[%0t] ASSERT FAILED: Parity Bit incorrect. Expected: %b. Real: %b", $time, 1'b1, data_out);
                end
            endcase 
            for(int i = 0; i < oversampling_factor; i ++) begin
                @(negedge uut.oversampling_tick);
            end
        end


        //Test Stop Bit
        assert(uut.tx_state == uut.STOP_BIT)
            $display("[%0t] ASSERT PASSED: Stop Bit, state correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Expected state: Stop Bit. Current State %s", $time, uut.tx_state.name());
        
        assert(data_out == 1'b1)
        else
            $error("[%0t] ASSERT FAILED: Expected stop bit: %b. Real bit: %b.", $time, 1'b1, data_out);

        for(int i = 0; i < oversampling_factor; i ++) begin
            @(negedge uut.oversampling_tick);
        end


        //Test Return to Idle
        assert(uut.tx_state == uut.IDLE)
            $display("[%0t] ASSERT PASSED: Idle, state correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Expected state: Idle. Current State %s", $time, uut.tx_state.name());
        
        assert(uut.available_to_send == 1'b1)
            $display("[%0t] ASSERT PASSED: Available to send correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Available to send incorrect, it should be active. %s", $time, uut.tx_state.name());

    end
    endtask

    initial begin
        send            = '0;
        byte_in         = '0;
        baud_rate       = '0;
        parity_bit_mode = '0;

        rst_n = '0;
        #(clk_period);
        rst_n = '1;
        #(clk_period);

        send_byte(8'b01111110, 3'b000, 2'b00);
        send_byte(8'b01111110, 3'b010, 2'b01);
        send_byte(8'b01111110, 3'b001, 2'b01);
        send_byte(8'b01111110, 3'b100, 2'b10);
        send_byte(8'b01111110, 3'b111, 2'b00);

        send_byte(8'b01111100, 3'b000, 2'b00);
        send_byte(8'b01111100, 3'b010, 2'b01);
        send_byte(8'b01111100, 3'b001, 2'b01);
        send_byte(8'b01111100, 3'b100, 2'b10);
        send_byte(8'b01111100, 3'b111, 2'b00);


        send = '0;
        @(negedge clk);
        byte_in = 8'hFF;
        #(clk_period);
        send = '1;
        #(10*clk_period);
        byte_in = 8'h00;
        #(clk_period)
        assert(uut.byte_to_send == 8'hFF)
            $display("[%0t] ASSERT PASSED: It does not accepts a new byte when sending another, as expected", $time);
        else
            $error("[%0t] ASSERT FAILED: It accepts a new byte when sending another", $time);
        #(clk_period)




        $finish;

    end

endmodule
