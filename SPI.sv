`timescale 1ns/1ps;

module spi_master(
    input clk, rst,
    input cpol, cpha,
    output [1:0] mode,
    input [7:0] tx_byte,
    output [7:0] rx_byte,
    output reg ss,
    output sck,
    input start,
    output reg mosi,
    input miso,
    output reg spi_lead, spi_trail,
    output reg done
);

    // GENERATION OF CLOCK

    localparam clk_frequency = 80; // 80MHz
    localparam spi_frequency = 10; // 10MHz

    localparam half_clk = clk_frequency/(spi_frequency*2);

    int clk_count;
    reg temp_sck;
    reg buf_start;

    always@(posedge clk) begin
        buf_start <= start;
    end

    always@(posedge clk, posedge rst) begin
        if(rst) begin
            clk_count <=0;
            temp_sck <= cpol;
            spi_lead <= 0;
            spi_trail <= 0;
        end
        else begin
            if(buf_start) begin
                spi_lead <= 1'b0;
                spi_trail <= 1'b0;
                if(clk_count == half_clk - 1) begin
                    temp_sck <= ~temp_sck;
                    clk_count <= clk_count + 1;
                    spi_lead <= 1'b1;
                end
                else if(clk_count == (half_clk*2 - 1)) begin
                    temp_sck <= ~temp_sck;
                    clk_count <= 0;
                    spi_trail <= 1'b1;
                end
                else begin
                    clk_count <= clk_count + 1;
                end
            end
            else begin
                clk_count <= 0;
                spi_lead <= 0;
                spi_trail <= 0;
                temp_sck <= cpol;
            end
        end
    end

    assign sck = temp_sck;
    assign mode = {cpol, cpha};

    // FSM FOR MOSI TRANSMISSION

    parameter IDLE_TX = 0;
    parameter HOLD_TX = 1;
    parameter SHIFT_TX = 2;
    parameter STOP_TX = 3;

    reg [1:0] state_tx;
    reg [7:0] tx_temp;
    reg [2:0] txdata_count = 3'b111;

    always@(posedge clk, posedge rst) begin
        if(rst) begin
            state_tx <= IDLE_TX;
            tx_temp <= 0;
            txdata_count = 3'b111;
            done <= 1'b0;
        end
        else begin
            case(state_tx)
                IDLE_TX: begin
                    if(buf_start) begin
                        tx_temp <= tx_byte;
                        txdata_count <= 3'b111;
                        done <= 1'b0;
                        ss <= 1'b0;
                        if(cpha == 1'b0) begin
                            state_tx <= HOLD_TX;
                        end
                        else if(cpha == 1'b1) begin
                            state_tx <= SHIFT_TX;
                        end
                    end
                    else begin
                        tx_temp <= 0;
                        state_tx <= IDLE_TX;
                        ss <= 1'b1;
                    end
                end
                HOLD_TX: begin
                    if(spi_lead) begin // HOLDING OF DATA AFTER HALF CYCLE
                        mosi <= tx_temp[txdata_count];
                        txdata_count <= txdata_count - 1;
                        state_tx <= SHIFT_TX;
                    end
                end
                SHIFT_TX: begin
                    if ((cpha == 0 && spi_trail) || (cpha == 1 && spi_lead)) begin
                        mosi <= tx_temp[txdata_count];
                        if(txdata_count!=0) begin
                            state_tx <= SHIFT_TX;
                            txdata_count <= txdata_count - 1;
                        end
                        else begin
                            state_tx <= STOP_TX;
                        end
                    end
                end
                STOP_TX: begin
                    state_tx <= IDLE_TX;
                    done <= 1'b1;
                end
            endcase
        end
    end

    // FSM FOR MISO RECEPTION

    parameter IDLE_RX = 4;
    parameter SAMPLE_RX = 5;
    parameter STOP_RX = 6;

    reg [2:0] state_rx;
    reg [7:0] rx_temp;
    reg [2:0] rxdata_count = 3'b111;

    always@(posedge clk, posedge rst) begin
        if(rst) begin
            state_rx <= IDLE_RX;
            rxdata_count <= 3'b111;
            rx_temp <= 0;
        end
        else begin
            case(state_rx)
                IDLE_RX: begin
                    if(buf_start) begin
                        rx_temp <= 0;
                        rxdata_count <= 3'b111;
                        state_rx <= SAMPLE_RX;
                    end
                    else begin
                        state_rx <= IDLE_RX;
                        rx_temp <= 0;
                    end
                end
                SAMPLE_RX: begin
                    if ((cpha == 0 && spi_lead) || (cpha == 1 && spi_trail)) begin
                        rx_temp[rxdata_count] <= miso;
                        if (rxdata_count != 0) begin
                            rxdata_count <= rxdata_count - 1;
                            state_rx <= SAMPLE_RX;
                        end
                        else begin
                            state_rx <= STOP_RX;
                        end
                    end
                end
                STOP_RX: begin
                    state_rx <= IDLE_RX;
                end
            endcase
        end
    end

    assign rx_byte = rx_temp;

endmodule