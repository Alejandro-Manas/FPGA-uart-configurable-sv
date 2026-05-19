`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Alejandro Mañas
//////////////////////////////////////////////////////////////////////////////////


module baud_gen_sim(

    );

    localparam oversampling_factor  = 16;
    localparam clk_freq             = 200000000.0;

    localparam clk_period           = 1000000000.0/clk_freq;
    localparam clk_semiperiod       = clk_period / 2.0;


    logic       clk;
    logic       rst_n;
    logic       clear;
    logic [2:0] baud_rate;
    logic       oversampling_tick;

    baud_gen #(
        .oversampling_factor    (oversampling_factor),
        .clk_freq               (clk_freq)
    ) uut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        .clear                  (clear),
        .baud_rate              (baud_rate),
        .oversampling_tick      (oversampling_tick)
    );

    always begin
        clk = 0; #clk_semiperiod;
        clk = 1; #clk_semiperiod;
    end

    task test_baud_rate (
        logic [2:0] baud_rate_test
    );
    begin
        int intial_time, final_time, clk_cycles;
        case (baud_rate_test)
            3'b000  :   $display("[%0t] Begining test at 9600 bauds.", $time);
            3'b001  :   $display("[%0t] Begining test at 1920 bauds.", $time);
            3'b010  :   $display("[%0t] Begining test at 38400 bauds.", $time);
            3'b011  :   $display("[%0t] Begining test at 57600 bauds.", $time);
            3'b100  :   $display("[%0t] Begining test at 115200 bauds.", $time);
            default :   $display("[%0t] Not valid value for baud_rate selector. Begining test at 9600 bauds for default.", $time);
        endcase 

        @(posedge clk);
        baud_rate = baud_rate_test;
        clear = '1;
        #(5*clk_period + clk_semiperiod);
        clear = '0;
        wait(clk);
        intial_time   = $time;
        wait(oversampling_tick == '1);
        final_time      = $time;

        clk_cycles = int'((final_time - intial_time) / clk_period);

        assert (clk_cycles == int'(uut.counter_max))
            $display("[%0t] Test passed succesfully", $time);
        else
            $error("[%0t] ASSERT FAILED: Cycles waited: %d. Cycles expected: %d", $time, clk_cycles, uut.counter_max);

        #(2*clk_period);
        wait(oversampling_tick == '1);
        intial_time = final_time;
        clk_cycles = int'(($time - intial_time)/clk_period);

        assert (clk_cycles == int'(uut.counter_max))
            $display("[%0t] Test passed succesfully", $time);
        else
            $error("[%0t] ASSERT FAILED: Cycles waited: %d. Cycles expected: %d", $time, clk_cycles, uut.counter_max);
    end 
    endtask

    initial begin
        rst_n       = '0;
        clear       = '0;
        baud_rate   = '0;
        #(10*clk_period);
        rst_n       = '1;

        //Testing the clear
        #(12*clk_period);
        assert(int'(uut.counter) != 0)
        else
            $error("[%0t] ASSERT FAILED: The module is not counting.", $time);

        #(clk_period);
        clear = '1;
        #(clk_period);
        assert(int'(uut.counter) == 0)
            $display("[%0t] Clear functionality works as expexted.", $time);
        else
            $error("[%0t] ASSERT FAILED: Clear functionality is not working", $time);
        //End of clear test

        test_baud_rate(3'b000);
        test_baud_rate(3'b001);
        test_baud_rate(3'b010);
        test_baud_rate(3'b011);
        test_baud_rate(3'b100);
        test_baud_rate(3'b101);
        test_baud_rate(3'b110);
        test_baud_rate(3'b111);

     

        $finish;
    end
endmodule
