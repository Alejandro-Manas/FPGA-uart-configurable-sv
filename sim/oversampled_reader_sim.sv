`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module oversampled_reader_sim(

    );

    localparam oversampling_factor  = 16;
    localparam clk_freq             = 200000000.0;

    localparam clk_period           = 1000000000.0/clk_freq;
    localparam clk_semiperiod       = clk_period / 2.0;

    logic clk;
    logic rst_n;
    logic read;
    logic oversampling_tick;
    logic data_in;

    logic data_ready;
    logic data_out;

    oversampled_reader #(
        .oversampling_factor    (oversampling_factor)
    ) uut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .read                   (read),
        .oversampling_tick      (oversampling_tick),
        .data_in                (data_in),
        .data_ready             (data_ready),
        .data_out               (data_out)
    );

    always begin
        clk = 0; #clk_semiperiod;
        clk = 1; #clk_semiperiod;
    end

    task test_reading (
        logic [oversampling_factor-1 : 0] data_in_sim,
        logic  expected_result
    );
    begin
        read = '0;
        #(2*clk_period);
        @(negedge clk);

        read = '1;

        for(int i = 0; i < oversampling_factor; i++) begin
            oversampling_tick = '0;
            #(clk_period);
            oversampling_tick = '1;
            data_in           = data_in_sim[i];
            #(clk_period);
        end

        assert(data_ready)
            $display("[%0t] ASSERT PASSED: Data ready working as expected", $time);
        else
            $error("[%0t] ASSERT FAILED: Data ready not working", $time);
        
        assert(data_out == expected_result)
            $display("[%0t] ASSERT PASSED: Data out correct", $time);
        else
            $error("[%0t] ASSERT FAILED: Data out not correct", $time);
    end
    endtask

    initial begin
        rst_n               = '0;
        read                = '0;
        oversampling_tick   = '0;
        data_in             = '0; 

        #(3*clk_period);

        rst_n = '1;

        //Testing that it doesn't read without "read" enable
        for(int i = 0; i < oversampling_factor; i++) begin
            #(clk_period);
            oversampling_tick = '1;
            #(clk_period);
            oversampling_tick = '0;
        end

        assert (data_ready == '0)
            $display("[%0t] ASSERT PASSED: Read functionality working when not active", $time);
        else
            $error("[%0t] ASSERT FAILED: Read functionality not working when not active", $time);
        
        #(oversampling_factor*clk_period);

        //Testing if it reads with "read" enable
        read = '1;
        for(int i = 0; i < oversampling_factor; i++) begin
            #(clk_period);
            oversampling_tick = '1;
            #(clk_period);
            oversampling_tick = '0;
        end

        assert (data_ready == '1)
            $display("[%0t] ASSERT PASSED: Read functionality working when active", $time);
        else
            $error("[%0t] ASSERT FAILED: Read functionality not working when active", $time); 

        #(oversampling_factor*clk_period);

        //Testing reading  without noise
        test_reading('1, '1);
        test_reading('0, '0);

        //Testing reading whith little noise
        test_reading(16'hFDEF, '1); //1111_1101_1110_1111
        test_reading(16'h0420, '0); //0000_0100_0010_0000

        //Testing with a slow change in the value
        test_reading(16'hFFF0, '1); //1111_1111_1111_0000

        #(clk_period);
        read = '1;

        for(int i = 0; i < 5*oversampling_factor; i++) begin
            #(clk_period);
            oversampling_tick = '1;
            #(clk_period);
            oversampling_tick = '0;
        end

        $finish;
    end

endmodule
