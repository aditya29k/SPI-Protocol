`timescale 1ns/1ps

interface SPI_intf;
    logic clk, rst;
    logic cpol, cpha;
  	logic [1:0] mode;
  	logic [7:0] tx_byte, rx_byte;
    logic ss;
    logic sck;
    logic start;
    logic mosi;
    logic miso;
    logic spi_lead, spi_trail;
    logic done;
endinterface

module tb;

    SPI_intf intf();
  
    spi_master DUT (
        .clk(intf.clk),
        .rst(intf.rst),
        .cpol(intf.cpol),
        .cpha(intf.cpha),
        .start(intf.start),
        .tx_byte(intf.tx_byte),
        .mode(intf.mode),
        .mosi(intf.mosi),
        .rx_byte(intf.rx_byte),
        .miso(intf.miso),
        .ss(intf.ss),
        .sck(intf.sck),
        .spi_lead(intf.spi_lead),
        .spi_trail(intf.spi_trail),
        .done(intf.done)
    );
	
    initial begin
        intf.clk <= 0;
    end
    
    always #6.25 intf.clk = ~intf.clk;
  
    task reset();
        intf.rst <= 1'b1;
        intf.start <= 1'b0;
        intf.miso <= 1'b0;
        intf.cpol <= 1'b0;
        intf.cpha <= 1'b0;
        repeat(5) @(posedge intf.clk);
        intf.rst <= 1'b0;
    endtask
  
    task run_clk();
    
        @(posedge intf.clk);

        intf.cpol <= $urandom_range(0,1);
        intf.cpha <= $urandom_range(0,1);
        intf.tx_byte <= $urandom_range(1,29);
    
        @(posedge intf.clk);
    
        intf.start <= 1'b1;


    endtask

    task run_mosi();
        wait(intf.done == 1'b1);
    endtask

  	int count;

    task run_miso();
      count = 0;
        forever begin
            if ((intf.cpha == 0 && intf.spi_lead) || (intf.cpha == 1 && intf.spi_trail)) begin
              intf.miso <= $urandom_range(0,1);
              count++;
            end
          if(count == 8) begin
                break;
          end
          repeat(2)@(posedge intf.clk);
        end
    endtask
  
    task run();
        reset();
        run_clk();
        fork
            run_mosi();
            run_miso();
        join
        intf.start <= 1'b0;
    endtask
  
    initial begin
      run();
      $finish();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars();
    end

endmodule
