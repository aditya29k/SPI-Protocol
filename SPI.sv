`ifndef CLK_FREQUENCY
	`define CLK_FREQUENCY 80000000 // 80MHz
`endif

`ifndef SPI_FREQUENCY
	`define SPI_FREQUENCY 10000000 // 10MHz
`endif

`ifndef HALF_CLOCK
`define HALF_CLOCK (`CLK_FREQUENCY/(2*`SPI_FREQUENCY)) // 4
`endif

`ifndef DATA_WIDTH
	`define DATA_WIDTH 8
`endif

interface spi_intf;
  
  logic clk, rst;
  logic mosi, miso;
  logic ss;
  logic [`DATA_WIDTH-1:0] data_in, data_out;
  logic cpol, cpha;
  logic [1:0] mode;
  logic start;
  logic sck;
  
endinterface

module spi_master(
  input clk, rst,
  input start,
  input cpol, cpha,
  input [`DATA_WIDTH-1:0] data_in,
  output [`DATA_WIDTH-1:0] data_out,
  output sck,
  output [1:0] mode,
  output reg ss,
  output reg mosi,
  input miso
);
  
  // Generation of clock
  
  reg temp_sck;
  reg buf_start;
  
  reg spi_trail, spi_lead;
  integer count;
  
  always@(posedge clk) begin
    buf_start <= start;
  end
  
  always@(posedge clk) begin
    if(rst) begin
      temp_sck <= cpol;
      count <= 0;
      {spi_trail, spi_lead} <= 2'b00;
    end
    else begin
      if(buf_start) begin
        spi_lead <= 1'b0;
      	spi_trail <= 1'b0;
        if(count == `HALF_CLOCK-1) begin
          spi_lead <= 1'b1;
          temp_sck <= ~temp_sck;
          count <= count + 1;
        end
        else if(count == `HALF_CLOCK*2-1) begin
          spi_trail <= 1'b1;
          temp_sck <= ~temp_sck;
          count <= 0;
        end
        else begin
          count <= count + 1;
        end
      end
      else begin
        temp_sck <= cpol;
        spi_trail <= 1'b0;
        spi_lead <= 1'b0;
        count <= 0;
      end
    end
  end
  
  assign sck = temp_sck;
  assign mode = {cpol, cpha};
  
  // FSM for MOSI
  
  typedef enum bit [1:0] {IDLE_TX, HOLD_TX, SHIFT_TX, STOP_TX} states_tx;
  states_tx state_tx;
  
  reg [`DATA_WIDTH-1:0] temp_din;
  integer data_count;
  
  always@(posedge clk) begin
    if(rst) begin
      data_count <= 7;
      temp_din <= 0;
      state_tx <= IDLE_TX;
      mosi <= 1'b0;
      ss <= 1'b1;
    end
    else begin
      case(state_tx)
        
        IDLE_TX: begin
          if(buf_start) begin
            temp_din <= data_in;
            ss <= 1'b0;
            data_count <= 7;
            if(cpha == 1'b0) begin
              state_tx <= HOLD_TX;
            end
            else begin
              state_tx <= SHIFT_TX;
            end
          end
          else begin
            temp_din <= 0;
            state_tx <= IDLE_TX;
            ss <= 1'b1;
          end
        end
        
        HOLD_TX: begin
          if(spi_lead) begin
            mosi <= temp_din[data_count];
            data_count <= data_count - 1;
            state_tx <= SHIFT_TX;
          end
        end
        
        SHIFT_TX: begin
          if((cpha == 1'b0 && spi_trail)||(cpha == 1'b1 && spi_lead)) begin
            mosi <= temp_din[data_count];
            if(data_count!=0) begin
              state_tx <= SHIFT_TX;
              data_count <= data_count-1;
            end
            else begin
              state_tx <= STOP_TX;
            end
          end
        end
        
        STOP_TX: begin
          state_tx <= IDLE_TX;
        end
        
      endcase
    end
  end
  
  // FSM for MISO
  
  typedef enum bit [1:0] {IDLE_RX, SAMPLE_RX, STOP_RX} states_rx;
  states_rx state_rx;
  
  reg [`DATA_WIDTH-1:0] temp_dout;
  integer data_count1;
  
  always@(posedge clk) begin
    if(rst) begin
      data_count1 <= 0;
      temp_dout <= 0;
      state_rx <= IDLE_RX;
    end
    else begin
      case(state_rx) 
        
        IDLE_RX: begin
          if(buf_start) begin
            temp_dout <= 0;
            state_rx <= SAMPLE_RX;
            data_count1 <= 0;
          end
          else begin
            state_rx <= IDLE_RX;
            temp_dout <= 0;
          end
        end
        
        SAMPLE_RX: begin
          if((cpha == 1'b0 && spi_lead) || (cpha == 1'b1 && spi_trail)) begin
            temp_dout[7-data_count1] <= miso;
            if(data_count1 == 7) begin
              data_count1 <= 0;
              state_rx <= STOP_RX;
            end
            else begin
              data_count1 <= data_count1 + 1;
              state_rx <= SAMPLE_RX;
            end
          end
        end
        
        STOP_RX: begin
          state_rx <= IDLE_RX;
        end
        
      endcase
    end
  end
  
  assign data_out = temp_dout;
  
endmodule
