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

class object;
  
  rand bit [`DATA_WIDTH-1:0] data_in; // master sends this to slave
  rand bit cpol, cpha;
  
endclass

module tb;
  
  spi_intf intf();
  
  spi_master DUT (.clk(intf.clk), .rst(intf.rst), .start(intf.start), .cpol(intf.cpol), .cpha(intf.cpha), .data_in(intf.data_in), .data_out(intf.data_out), .sck(intf.sck), .mode(intf.mode), .ss(intf.ss), .mosi(intf.mosi), .miso(intf.miso));
  
  object obj;
  
  initial begin
    intf.clk <= 1'b0;
  end
  
  always #6.25 intf.clk <= ~intf.clk;
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
  task reset();
    intf.rst <= 1'b1;
    intf.miso <= 1'b0;
    intf.data_in <= 0;
    intf.cpol <= 1'b0;
    intf.cpha <= 1'b0;
    intf.start <= 1'b0;
    repeat(10)@(posedge intf.clk);
    intf.rst <= 1'b0;
    $display("System Reseted");
    $display("----------------");
  endtask
  
  reg [`DATA_WIDTH-1:0] temp;
  int count;

  
  task mosi(object obj);
    $display("---------------");
    $display("MOSI TRANSFER");
    count = 0;
    forever begin
      if((intf.cpha == 1'b0 && DUT.spi_trail)||(intf.cpha == 1'b1 && DUT.spi_lead)) begin
        temp[7:0] <= {temp[6:0],intf.mosi};
        $display("temp: %b", temp);
        count++;
      end
      if(count == 9) begin
        break;
      end
      @(posedge intf.clk);
    end
    
    if(temp == obj.data_in) begin
      $display("SLAVE RECEIVED CORRECT DATA");
    end
    else begin
      $display("SLAVE RECEIVED INCORRECT DATA");
    end
    
    $display("--------------");
    
  endtask
  
  int count1;
  
  task miso(object obj);
    count1 = 0;
    forever begin
      if((intf.cpha == 1'b0 && DUT.spi_lead)||(intf.cpha == 1'b1 && DUT.spi_trail)) begin
        intf.miso <= $urandom_range(0,1);
        count1++;
      end
      if(count1 == 9) break;
      @(posedge intf.clk);
    end
  endtask
  
  initial begin
    reset();
    
    obj = new();
    assert(obj.randomize()) else $error("RANDOMIZATION FAILED");
    
    $display("cpol: %0d, cpha: %0d data_in: %b", obj.cpol, obj.cpha, obj.data_in);
    intf.start <= 1'b1;
    intf.cpol <= obj.cpol;
    intf.cpha <= obj.cpha;
    intf.data_in <= obj.data_in;
    
    fork
      mosi(obj);
      miso(obj);
    join
    $finish();
  end
  
endmodule
