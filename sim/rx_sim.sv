`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module rx_sim(

    );
    localparam oversampling_factor  = 16;
    localparam clk_freq             = 200000000.0;

    localparam clk_period           = 1000000000.0/clk_freq;
    localparam clk_semiperiod       = clk_period / 2.0;

    //Inputs
    logic           clk;
    logic           rst_n;
    logic           data_in_rx;
    logic [2 : 0]   baud_rate;
    logic [1 : 0]   parity_bit;
    //Outputs
    logic           byte_ready;
    logic           byte_valid;
    logic [7 : 0]   byte_out;

    //Module instanciation
    rx_module #(
        .clk_freq               (clk_freq),
        .oversampling_factor    (oversampling_factor)
    ) uut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .data_in_rx             (data_in_rx),
        .baud_rate              (baud_rate),
        .parity_bit             (parity_bit),

        .byte_ready             (byte_ready),
        .byte_valid             (byte_valid),
        .byte_out               (byte_out)
    );

    localparam int B9600   = clk_freq / (9600   * oversampling_factor);
    localparam int B19200  = clk_freq / (19200  * oversampling_factor);
    localparam int B38400  = clk_freq / (38400  * oversampling_factor);
    localparam int B57600  = clk_freq / (57600  * oversampling_factor);
    localparam int B115200 = clk_freq / (115200 * oversampling_factor);
    int SIMULATION_BUAD_RATE;

    //Clk declaration 
    always begin
        clk = 0; #clk_semiperiod;
        clk = 1; #clk_semiperiod;
    end

    task send_byte (
        int         baud_rate_int,              // 9600 - 19200 - 38400 - 57600 - 115200
        int         baud_rate_ticks,
        int         expected_result,             // 0 <- Not valid byte   1 <- Valid byte
        logic [7:0] byte_sim,
        int         parity_bit_config,          // 0 <- No parity bit    1 <- Odd parity    2 <- Even parity
        logic       parity_bit_sim,
        logic       end_bit_sim
    );
    begin

        //Ajusting parity bit configuration
        if(parity_bit_config ==  1) begin
            parity_bit = 2'b10;
        end
        else if(parity_bit_config == 2) begin
            parity_bit = 2'b01;
        end
        else begin
            parity_bit = 2'b00;
        end

        //Adjusting baud rate configuration
        $display("[%0t] Simulation %d bauds test. No parity. No errors in comunication.", $time, baud_rate_int);
        if(baud_rate_int == 9600) begin
            baud_rate = 3'b000;
            SIMULATION_BUAD_RATE = B9600;
        end 
        else if(baud_rate_int == 19200) begin
            baud_rate = 3'b001;
            SIMULATION_BUAD_RATE = B19200;
        end
        else if(baud_rate_int == 38400) begin
            baud_rate = 3'b010;
            SIMULATION_BUAD_RATE = B38400;
        end
        else if(baud_rate_int == 57600) begin
            baud_rate = 3'b011;
            SIMULATION_BUAD_RATE = B57600;
        end
        else if(baud_rate_int == 115200) begin
            baud_rate = 3'b100;
            SIMULATION_BUAD_RATE = B115200;
        end
        else begin
            $display("ERROR: baud_rate_int not valid. Valid values: 9600, 19200, 38400, 57600 and 115200");
            $finish;
        end

        rst_n       = '1;
        data_in_rx  = '1; // Starts at one to confirm taht the baud counter will start when it's put to 0 from 1.
        #(4*clk_period);
        data_in_rx  = '0; // Inicialization of transmission

        #(10*clk_period)
        assert (uut.rx_state == uut.START_BIT) 
            $display("[%0t] RX state correct(START_BIT).", $time);
        else 
            $error("[%0t] ASSERT FAILED: RX state incorrect. should be START_BIT and is %h.", $time, uut.rx_state);

        #(oversampling_factor * SIMULATION_BUAD_RATE * clk_period);
        assert (uut.rx_state == uut.READ_BYTE) 
            $display("[%0t] RX state correct(READ_BYTE).", $time);
        else 
            $error("[%0t] ASSERT FAILED: RX state incorrect. should be READ_BYTE and is %h.", $time, uut.rx_state);

        for (int i = 0; i < 8; i++) begin
            data_in_rx = byte_sim[i];
            #(oversampling_factor * SIMULATION_BUAD_RATE * clk_period);
        end

        if(parity_bit_config > 0) begin
            data_in_rx = parity_bit_sim;
            assert (uut.rx_state == uut.PARITY_BIT) 
                $display("[%0t] RX state correct(PARITY_BIT).", $time);
            else 
                $error("[%0t] ASSERT FAILED: RX state incorrect. should be PARITY_BIT and is %h.", $time, uut.rx_state);
            #(oversampling_factor * SIMULATION_BUAD_RATE * clk_period);
        end

        data_in_rx = end_bit_sim;
        assert (uut.rx_state == uut.STOP_BIT) 
            $display("[%0t] RX state correct(STOP_BIT).", $time);
        else 
            $error("[%0t] ASSERT FAILED: RX state incorrect. should be STOP_BIT and is %h.", $time, uut.rx_state);
        

        
        wait(uut.rx_state == uut.IDLE);
        
        assert (byte_ready) 
            $display("[%0t] Byte ready active.", $time);
        else 
            $error("[%0t] ASSERT FAILED: Byte ready not active, expected a '1", $time);

        assert (byte_valid == expected_result) 
            $display("[%0t] Byte valid working as expected.", $time);
        else 
            $error("[%0t] ASSERT FAILED: Byte valid is %b and should be %d", $time, byte_valid, expected_result);

        assert (byte_out == byte_sim) 
            $display("[%0t] Byte recieved correctly.", $time);
        else 
            $error("[%0t] ASSERT FAILED: Byte recieved %h while expected is %h.", $time, byte_out, byte_sim);
        
    end
    endtask

    //Simulation begin
    initial begin
        rst_n       = '0;
        data_in_rx  = '1;
        baud_rate   = '0;   // 000 <- 9600  001 <- 19200    010 <- 38400    011 <- 57600    100 <- 115200
        parity_bit  = '0;
        //byte_sim    = '0;

        #(10*clk_period);

        //Simulation 115200 bauds. No parity. No errors.
        //---------------------------------------------------
        send_byte(115200, 0, 1, 8'b11100111, 0, 0, 1);
        //---------------------------------------------------

        //Simulation 9600 bauds. Even parity. No errors.
        //---------------------------------------------------
        send_byte(9600, 0, 1, 8'b10011001, 2, 0, 1);
        //---------------------------------------------------

        //Simulation 115200 bauds. Odd parity. Parity error.
        //---------------------------------------------------
        send_byte(115200, 0, 0, 8'h11111111, 1, 0, 1);
        //---------------------------------------------------
        
        $finish;
    end
endmodule
