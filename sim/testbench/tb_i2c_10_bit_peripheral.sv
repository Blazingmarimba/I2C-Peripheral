`timescale 1ns/100ps

//===================================================================
//  File: tb_i2c_peripheral.sv
//  Author: Michael Bjerregaard
//  Description: Testbench I2C peripheral
//  Date: March 31, 2025
//===================================================================


module tb_i2c_10_bit_peripheral ();

    parameter I2C_PERIPHERAL_ADDRESS = 10'h313;


    initial
        $timeformat(-9, 0, " ns", 10);

    logic sys_clk = 0;
    logic rst_n;

    tri scl;
    tri sda;

    logic scl_enable = 0;
    logic scl_drv = 1;
    logic sda_drv = 1;

    logic[7:0] register_address;
    logic read_enable;
    logic[7:0] read_register_data;
    logic read_valid = 0;
    logic read_ack;

    logic[7:0] write_register_data;
    logic write_valid;
    logic write_ack = 0;


    int total_errors = 0;

    i2c_peripheral #(.I2C_PERIPHERAL_ADDRESS(I2C_PERIPHERAL_ADDRESS), .ADDRESS_SIZE(10)) DUT (.i_sys_clk(sys_clk), .i_rst_n(rst_n), .io_scl(scl), .io_sda(sda), .o_register_address(register_address), .o_read_enable(read_enable), .i_register_data(read_register_data), .i_read_valid(read_valid), .o_read_ack(read_ack), .o_register_data(write_register_data), .o_write_valid(write_valid), .i_write_ack(write_ack));

    pullup (scl);
    pullup (sda);

    assign scl = (scl_drv == 0) ? 1'b0 : 1'bZ;
    assign sda = (sda_drv == 0) ? 1'b0 : 1'bZ;


    logic ack;

    // Setup clock
    initial
    begin
        forever
        begin
            if(scl_enable)
                #1250ns scl_drv = ~scl_drv;
            else
                #5 scl_drv = 1;
        end
    end
    always
        #5 sys_clk = ~sys_clk; // Create 100 MHz system clock

    // Perform inital system reset
    initial
    begin
        rst_n = 1'b0;
        #100 rst_n = 1'b1;
        // Test single byte writes and reads
        i2c_write_byte(I2C_PERIPHERAL_ADDRESS[6:0], 8'h55, 8'hAA);
        i2c_10_bit_write_byte(I2C_PERIPHERAL_ADDRESS, 8'h55, 8'hAA);
        // i2c_read_byte(I2C_PERIPHERAL_ADDRESS, 8'hAA, 8'h55);

        //Test reading to another address
        i2c_10_bit_write_byte(I2C_PERIPHERAL_ADDRESS + 1'b1, 8'h55, 8'hAA);

        $display("[%0t] Testbench done. Total Errors: %0d", $time, total_errors);
        $finish;
    end

    task transmit_byte(input[7:0] data, input ack);
        for(int i = 7; i >= 0; i--)
        begin
            @(negedge scl);
            sda_drv = data[i];
        end
        @(negedge scl);
        sda_drv = 1;
        @(posedge scl);
        if(sda != ack)
        begin
            $display("ERROR: [%0t] Expected ACK/NACK of %b, got %b", $time, ack, sda);
            total_errors = total_errors + 1;
        end
    endtask

    /*
        logic read_enable;
        logic[7:0] read_register_data;
        logic read_valid;
        logic read_ack;
    */
    task receive_byte(input[7:0] data, input nack, output[7:0] r_data);
        for(int i = 7; i >= 0; i--)
        begin
            @(posedge scl);
            r_data[i] = sda;
        end
        @(negedge scl);
        sda_drv = nack;
        @(posedge scl);
        @(negedge scl);
        sda_drv = 1'b1;
        #1ns;
    endtask

    task start_condtion();
        sda_drv = 1'b0;
        #0.6us;
        scl_enable = 1'b1;
        #1ns;
    endtask

    task repeat_start();
        if(scl == 1'b1)
            @(negedge scl);
        sda_drv = 1'b1;
        scl_enable = 1'b0;
        wait(scl == 1'b1);
        #0.6us;
        sda_drv = 1'b0;
        #0.6us;
        scl_enable = 1'b1;
        #1ns;
    endtask

    task stop_condition();
        wait(scl == 1'b0);
        sda_drv = 1'b0;
        scl_enable = 1'b0;
        wait(scl == 1'b1);
        #0.6us;
        sda_drv = 1'b1;
        #1ns;
    endtask

    // Task to write to I2C Peripheral
    task i2c_write_byte(input[6:0] i2c_address, input [7:0] reg_address, data);
        begin
            if(i2c_address === I2C_PERIPHERAL_ADDRESS)
                ack = 0;
            else
                ack = 1;

            $display("%0t: Writing to device 0x%H, register 0x%H, data 0x%H", $time,  i2c_address, reg_address, data);
            sda_drv = 1'b0; //Send START condition

            $display("%0t: Sending START condition", $time);
            #0.6us scl_enable = 1'b1;             // Minimum fat-mode start hold time
            $display("%0t: Sending I2C Address", $time);
            transmit_byte({i2c_address, 1'b0}, ack);
            $display("%0t: Sending Reg Address", $time);
            transmit_byte(reg_address, ack);
            $display("%0t: Sending Data", $time);
            transmit_byte(data, ack);
            if(register_address !== reg_address && i2c_address == I2C_PERIPHERAL_ADDRESS)
            begin
                $display("ERROR: [%0t] Expected register_address %h, got %h", $time, reg_address, register_address);
                total_errors = total_errors + 1;
            end
            if(i2c_address == I2C_PERIPHERAL_ADDRESS)
            begin
                if(write_register_data !== data)
                begin
                    $display("[%0t] Expected data %h, got %h", $time, data, write_register_data);
                    total_errors = total_errors + 1;
                end
                if(write_valid === 0)
                begin
                    $display("[%0t] Expected data to be valid, got %b", $time, write_valid);
                    total_errors = total_errors + 1;
                end
                else
                    write_ack = 1;
            end
            else if (write_valid === 1)
            begin
                $display("[%0t] Expected data to be not valid, got %b", $time, write_valid);
                total_errors = total_errors + 1;
            end
            $display("%0t: Sending STOP condition", $time);
            @(negedge scl);
            write_ack = 0;
            stop_condition();
            #1.3us;
        end
    endtask

    logic [7:0] r_data;
    task i2c_10_bit_write_byte(input[9:0] i2c_address, input [7:0] reg_address, data);
        begin
            

            $display("%0t: Writing to device 0x%H, register 0x%H, data 0x%H", $time,  i2c_address, reg_address, data);
            sda_drv = 1'b0; //Send START condition

            $display("%0t: Sending START condition", $time);
            #0.6us scl_enable = 1'b1;             // Minimum fat-mode start hold time
            $display("%0t: Sending I2C Address", $time);
            if(i2c_address[9:8] == I2C_PERIPHERAL_ADDRESS[9:8])
                ack = 0;
            else
                ack = 1;
            transmit_byte({5'h1E, i2c_address[9:8], 1'b0}, ack);
            if(i2c_address[7:0] == I2C_PERIPHERAL_ADDRESS[7:0])
                ack = 0;
            else
                ack = 1;
            transmit_byte(i2c_address[7:0], ack);
            $display("%0t: Sending Reg Address", $time);
            transmit_byte(reg_address, ack);
            $display("%0t: Sending Data", $time);
            transmit_byte(data, ack);
            if(register_address !== reg_address && i2c_address == I2C_PERIPHERAL_ADDRESS)
            begin
                $display("ERROR: [%0t] Expected register_address %h, got %h", $time, reg_address, register_address);
                total_errors = total_errors + 1;
            end
            if(i2c_address == I2C_PERIPHERAL_ADDRESS)
            begin
                if(write_register_data !== data)
                begin
                    $display("[%0t] Expected data %h, got %h", $time, data, write_register_data);
                    total_errors = total_errors + 1;
                end
                if(write_valid === 0)
                begin
                    $display("[%0t] Expected data to be valid, got %b", $time, write_valid);
                    total_errors = total_errors + 1;
                end
                else
                    write_ack = 1;
            end
            else if (write_valid === 1)
            begin
                $display("[%0t] Expected data to be not valid, got %b", $time, write_valid);
                total_errors = total_errors + 1;
            end
            $display("%0t: Sending STOP condition", $time);
            @(negedge scl);
            write_ack = 0;
            stop_condition();
            #1.3us;
        end
        // Task to read from I2C Peripheral. Does not set address
    endtask

endmodule
