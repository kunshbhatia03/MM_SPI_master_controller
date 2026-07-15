`timescale 1ns / 1ps

// Sweeps all 4 CPOL/CPHA combinations through the register-mapped bus
// interface, in loopback (MOSI tied to MISO), checking the transmitted
// byte comes back unchanged in every mode. This exists purely as a
// pre-publish sanity check for the mosi-preload fix in spi_master.v -
// tb_spi_top.v remains the primary functional testbench.
module tb_mode_sweep;

    reg clk = 0;
    reg rst_n = 0;
    reg [1:0] bus_addr;
    reg [7:0] bus_wdata;
    reg bus_wr_en = 0;
    reg bus_rd_en = 0;
    wire [7:0] bus_rdata;
    wire sclk, mosi, cs_n;
    wire miso = mosi;

    localparam ADDR_CR  = 2'b00;
    localparam ADDR_SR  = 2'b01;
    localparam ADDR_TDR = 2'b10;
    localparam ADDR_RDR = 2'b11;

    integer pass_count = 0;
    integer fail_count = 0;

    spi_top uut (
        .clk(clk), .rst_n(rst_n),
        .bus_addr(bus_addr), .bus_wdata(bus_wdata),
        .bus_wr_en(bus_wr_en), .bus_rd_en(bus_rd_en), .bus_rdata(bus_rdata),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    always #10 clk = ~clk;

    task bus_write(input [1:0] addr, input [7:0] data);
        begin
            @(posedge clk);
            bus_addr = addr; bus_wdata = data; bus_wr_en = 1'b1;
            @(posedge clk);
            bus_wr_en = 1'b0;
        end
    endtask

    task bus_read(input [1:0] addr);
        begin
            @(posedge clk);
            bus_addr = addr; bus_rd_en = 1'b1;
            @(posedge clk);
            bus_rd_en = 1'b0;
            @(posedge clk);
        end
    endtask

    task check(input cond, input string msg);
        begin
            if (cond) begin pass_count = pass_count + 1; $display("  PASS: %s", msg); end
            else begin fail_count = fail_count + 1; $display("  FAIL: %s", msg); end
        end
    endtask

    task run_mode(input cpol_bit, input cpha_bit, input [7:0] test_byte);
        begin
            bus_write(ADDR_CR, {5'd0, cpha_bit, cpol_bit, 1'b1}); // spi_en=1
            bus_write(ADDR_TDR, test_byte);
            bus_read(ADDR_SR);
            while (bus_rdata[4] == 1'b1 || bus_rdata[2] == 1'b1) begin
                #40; bus_read(ADDR_SR);
            end
            bus_read(ADDR_RDR);
            check(bus_rdata === test_byte,
                  $sformatf("CPOL=%0d/CPHA=%0d loopback byte 0x%h", cpol_bit, cpha_bit, test_byte));
            bus_write(ADDR_CR, 8'h00); // disable before switching modes
        end
    endtask

    initial begin
        $display("=== SPI mode sweep (post-fix sanity check) ===");
        rst_n = 0; #50; rst_n = 1; #50;

        run_mode(1'b0, 1'b0, 8'hA5);
        run_mode(1'b0, 1'b1, 8'h96);
        run_mode(1'b1, 1'b0, 8'hC3);
        run_mode(1'b1, 1'b1, 8'h3C);

        $display("=== mode sweep complete: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0) $display("*** ALL MODE SWEEP TESTS PASSED ***");
        else $display("*** MODE SWEEP TESTS FAILED ***");
        $finish;
    end

    initial begin
        #50000;
        $display("WATCHDOG TIMEOUT");
        $finish;
    end

endmodule
