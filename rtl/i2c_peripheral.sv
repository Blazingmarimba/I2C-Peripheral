`default_nettype none
`timescale 1ns/100ps

//===================================================================
//  File: i2c_peripheral.sv
//  Author: Michael Bjerregaard
//  Description: I2C peripheral
//  Date: March 31, 2025
//===================================================================

module i2c_peripheral #(
        // parameters
        parameter SYS_CLOCK_FREQ = 100_000_000,

        parameter ADDRESS_SIZE = 7,
        parameter I2C_PERIPHERAL_ADDRESS = 7'h33,

        parameter SYNCHRONIZER = 1,

        parameter WATCHDOG_TIMER_COUNT = 15_000
    ) (
        // Standard system signals
        input wire logic i_sys_clk,
        input wire logic i_rst_n,

        // I2C signals
        inout wire logic io_scl, // Inout to be able to support clock stretching
        inout wire logic io_sda,

        // Register reading signals
        output logic[7:0] o_register_address,
        output logic o_read_enable,
        input wire logic[7:0] i_register_data,
        input wire logic i_read_valid,
        output wire logic o_read_ack,

        // Register Wrire signal
        output logic[7:0] o_register_data,
        output logic o_write_valid,
        input wire logic i_write_ack

    );

    // assign o_register_data = 8'h00;

    localparam WATCHDOG_TIMER_WIDTH = $clog2(WATCHDOG_TIMER_COUNT + 1);

    logic scl; // Synchronized SCL input.
    logic sda; // Synchronized SDA input.

    generate // Optionally synchronizes I2C signals using basic 2 Flip-Flop Synchronizer.
        if(SYNCHRONIZER)
        begin
            logic scl_sync_d;
            logic sda_sync_d;
            always_ff @(posedge i_sys_clk )
            begin
                scl_sync_d <= io_scl;
                scl <= scl_sync_d;

                sda_sync_d <= io_sda;
                sda <= sda_sync_d;
            end
        end
        else
        begin
            assign scl = io_scl;
            assign sda = io_sda;
        end
    endgenerate

    // START, STOP, repeated START condition detection
    logic scl_delay;
    logic sda_delay;

    always_ff @( posedge i_sys_clk )
    begin
        scl_delay <= scl;
        sda_delay <= sda;
    end

    logic sda_falling_edge;
    logic sda_rising_edge;

    assign sda_falling_edge = (sda_delay && !sda) ? 1'b1 : 1'b0;
    assign sda_rising_edge = (!sda_delay && sda) ? 1'b1 : 1'b0;

    logic scl_falling_edge;
    logic scl_rising_edge;

    assign scl_falling_edge = (scl_delay && !scl) ? 1'b1 : 1'b0;
    assign scl_rising_edge = (!scl_delay && scl) ? 1'b1 : 1'b0;

    logic start_condition;
    logic stop_condition;

    assign start_condition = (sda_falling_edge && scl) ? 1'b1 : 1'b0;
    assign stop_condition = (sda_rising_edge && scl) ? 1'b1 : 1'b0;

    logic [7:0] increment_counter;

    // Finit State Machine (FSM)

    logic watchdog_expire;
    logic byte_transmitted;

    // Signals for data transmition
    logic[7:0] data_register;
    logic[3:0] shift_counter;
    logic data_shift_enable;
    logic rw_n;

    logic peripheral_address_match;

    typedef enum logic[3:0] { IDLE, I2C_ADDRESS, OTHER_PERIPHERAL, ACK_ADDRESS, REG_ADDRESS, ACK_REG, WRITE_HOLD, WRITE, ACK_WRITE, READ_PREP, READ, READ_DONE, REPEAT_START, READ_INCREMENT, WRITE_INCREMENT, ERROR } FSM_States; // Need to add states to support 10-bit addresses

    FSM_States current_state;
    FSM_States next_state;

    always_ff @(posedge i_sys_clk )
    begin : FSM_State_update
        if(!i_rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    always_comb
    begin : FSM_State_Transition
        next_state = ERROR;

        // Normal state transitions
        case (current_state)
            IDLE:
                if (start_condition)
                    next_state = I2C_ADDRESS;
                else
                    next_state = IDLE;
            I2C_ADDRESS:
                if(byte_transmitted && peripheral_address_match)
                    next_state = ACK_ADDRESS;
                else if (byte_transmitted && !peripheral_address_match)
                    next_state = OTHER_PERIPHERAL;
                else
                    next_state = I2C_ADDRESS;
            OTHER_PERIPHERAL:
                if(stop_condition)
                    next_state = IDLE;
                else if(start_condition)
                    next_state = REPEAT_START;
                else
                    next_state = OTHER_PERIPHERAL;
            ACK_ADDRESS:
                if(scl_falling_edge && rw_n)
                    next_state = READ_PREP;
                else if (scl_falling_edge && !rw_n)
                    next_state = REG_ADDRESS;
                else
                    next_state = ACK_ADDRESS;
            //   default:
            REG_ADDRESS:
                if(byte_transmitted)
                    next_state = ACK_REG;
                else
                    next_state = REG_ADDRESS;
            ACK_REG:
                if(start_condition)
                    next_state = REPEAT_START;
                else if (stop_condition)
                    next_state = IDLE;
                else if (scl_falling_edge)
                    next_state = WRITE;
                else
                    next_state = ACK_REG;
            WRITE:
                if(start_condition)
                    next_state = REPEAT_START;
                else if (stop_condition)
                    next_state = IDLE;
                else if(byte_transmitted)
                    next_state = ACK_WRITE;
                else
                    next_state = WRITE;
            ACK_WRITE:
                if(scl_falling_edge)
                    next_state = WRITE_INCREMENT;
                else
                    next_state = ACK_WRITE;
            WRITE_INCREMENT:
                next_state = WRITE;

            READ_PREP:
                if (start_condition)
                    next_state = REPEAT_START;
                else if (stop_condition)
                    next_state = IDLE;
                else if(i_read_valid)
                    next_state = READ;
                else
                    next_state = READ_PREP;
            READ:
                if(byte_transmitted)
                    next_state = READ_INCREMENT;
                else
                    next_state = READ;
            READ_INCREMENT:
                next_state = READ_DONE;
            READ_DONE:
                if(scl_rising_edge && sda)
                    next_state = IDLE;
                else if (scl_falling_edge && !sda)
                    next_state = READ_PREP;
                else
                    next_state = READ_DONE;
            REPEAT_START:
                next_state = I2C_ADDRESS;
        endcase

        // Watchdog expire transition
        if (watchdog_expire)
            next_state = IDLE;

    end

    logic watchdog_run;
    logic send_data;
    logic receive_data;
    logic ack;

    always_comb
    begin : FSM_Outputs
        watchdog_run = 1'b1;
        send_data = 1'b0;
        receive_data = 1'b0;
        ack = 1'b0;
        o_read_enable = 1'b0;

        case (current_state)
            IDLE:
                watchdog_run = 1'b0;
            I2C_ADDRESS:
                receive_data = 1'b1;
            ACK_ADDRESS:
                ack = 1'b1;
            REG_ADDRESS:
                receive_data = 1'b1;
            ACK_REG:
                ack = 1'b1;
            WRITE:
                receive_data = 1'b1;
            ACK_WRITE:
                ack = 1'b1;
            READ_PREP:
                o_read_enable = 1'b1;
            READ:
                send_data = 1'b1;
            // default:
        endcase


    end

    always_ff @(posedge i_sys_clk)
    begin
        if (!i_rst_n)
            increment_counter <= 0;
        else if (current_state == I2C_ADDRESS)
            increment_counter <= 0;
        else if (current_state == READ_INCREMENT || current_state == WRITE_INCREMENT)
            increment_counter <= increment_counter + 1;
    end


    assign data_shift_enable = (receive_data && scl_rising_edge) ? 1'b1 :
           (send_data && scl_falling_edge) ? 1'b1 : 1'b0; // Shifts the data_register on the rising edge of SCL if controller is writing, on the falling edge of SCL if controller is reading

    assign rw_n = data_register[0];

    assign o_read_ack = (o_read_enable && i_read_valid) ? 1'b1 : 1'b0;

    always_ff @( posedge i_sys_clk )
    begin
        if(!i_rst_n)
            data_register <= 0;
        else if (o_read_enable && i_read_valid)
            data_register <= i_register_data;
        else if (data_shift_enable)
            if (receive_data)
                data_register <= {data_register[6:0], sda};
            else
                data_register <= {data_register[6:0], 1'b1};
    end

    always_ff @(posedge i_sys_clk)
        if (!i_rst_n)
            o_register_address <= 0;
        else
            if (current_state == REG_ADDRESS && next_state != REG_ADDRESS) // Needs updating to support auto-increment
                o_register_address <= data_register + increment_counter;

    assign io_sda = (send_data && !data_register[7]) ? 1'b0 :
           (ack) ? 1'b0 : 1'bZ;

    always_ff @(posedge i_sys_clk)
    begin
        if(!i_rst_n)
            shift_counter <= 0;
        else if ((send_data || receive_data) && data_shift_enable)
            shift_counter <= shift_counter + 1'b1;
        else if (!(send_data || receive_data))
            shift_counter <= 0;
    end

    assign byte_transmitted = (shift_counter == 4'd8 && scl_falling_edge) ? 1'b1 : 1'b0;

    assign peripheral_address_match = (data_register[7:1] == I2C_PERIPHERAL_ADDRESS) ? 1'b1 : 1'b0; // Only supports 7-bit addresses. Needs updating to support 10-bit address

    // Watchdog logic
    logic[WATCHDOG_TIMER_WIDTH-1:0] watchdog_timer;

    always_ff @(posedge i_sys_clk )
    begin : watchdog
        if(!i_rst_n)
            watchdog_timer <= WATCHDOG_TIMER_COUNT;
        else
            if (current_state != next_state || current_state == IDLE)
                watchdog_timer <= WATCHDOG_TIMER_COUNT;
            else if (watchdog_run)
                watchdog_timer <= watchdog_timer - 1;
    end

    assign watchdog_expire = (watchdog_timer == 0) ? 1'b1 : 1'b0;

endmodule
