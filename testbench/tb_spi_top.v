`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Description: Testbench to verify memory-mapped SPI master functionality 
//              using an internal loopback (MOSI connected to MISO).
//////////////////////////////////////////////////////////////////////////////////

module tb_spi_top;

    // Inputs to the DUT
    reg        clk;
    reg        rst_n;
    reg  [1:0] bus_addr;
    reg  [7:0] bus_wdata;
    reg        bus_wr_en;
    reg        bus_rd_en;
    
    // Outputs from the DUT
    wire [7:0] bus_rdata;
    wire       sclk;
    wire       mosi;
    wire       miso;
    wire       cs_n;

    // Register Address Map Localparams for Readability
    localparam ADDR_CR  = 2'b00; // Control Register
    localparam ADDR_SR  = 2'b01; // Status Register
    localparam ADDR_TDR = 2'b10; // TX Data Register
    localparam ADDR_RDR = 2'b11; // RX Data Register

    // Hardware Loopback: Route transmitted data directly back into the receiver
    assign miso = mosi;

    // Instantiate the Top-Level Module
    spi_top uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .bus_addr  (bus_addr),
        .bus_wdata (bus_wdata),
        .bus_wr_en (bus_wr_en),
        .bus_rd_en (bus_rd_en),
        .bus_rdata (bus_rdata),
        .sclk      (sclk),
        .mosi      (mosi),
        .miso      (miso),
        .cs_n      (cs_n)
    );

    // Generate 50 MHz System Clock
    always #10 clk = ~clk;

    // Bus Write Task: Simulates a processor writing to a peripheral register
    task bus_write(input [1:0] addr, input [7:0] data);
        begin
            @(posedge clk);
            bus_addr  = addr;
            bus_wdata = data;
            bus_wr_en = 1'b1;
            @(posedge clk);
            bus_wr_en = 1'b0;
            bus_addr  = 2'b00;
            bus_wdata = 8'h00;
        end
    endtask

    // Bus Read Task: Simulates a processor reading from a peripheral register
    task bus_read(input [1:0] addr);
        begin
            @(posedge clk);
            bus_addr  = addr;
            bus_rd_en = 1'b1;
            @(posedge clk);
            bus_rd_en = 1'b0;
            @(posedge clk); // Clock edge to let the read data stabilize on the bus
        end
    endtask

    // Main Stimulus Setup
    initial begin
        // Generate VCD file for GTKWave/Vivado waveform analysis
        $dumpfile("spi_fifo_regs.vcd");
        $dumpvars(0, tb_spi_top);
        
        // Initialize Inputs
        clk       = 1'b0;
        rst_n     = 1'b0;
        bus_addr  = 2'b00;
        bus_wdata = 8'h00;
        bus_wr_en = 1'b0;
        bus_rd_en = 1'b0;
        
        // Hold reset for 50ns
        #50;
        rst_n = 1'b1;
        #50;
        
        $display("[TB INFO] --- Starting SPI Peripheral Testbench ---");

        // Step 1: Check initial Status Register values (Should show TX Empty)
        bus_read(ADDR_SR);
        $display("[REG CHECK] Initial Status Register: 8'b%b", bus_rdata);
        
        // Step 2: Configure Control Register (Enable SPI = 1, CPOL = 0, CPHA = 0)
        $display("[TB ACTION] Enabling SPI Core in Mode 0...");
        bus_write(ADDR_CR, 8'h01); 
        
        // Step 3: Populate the TX FIFO by writing three distinct test bytes to TDR
        $display("[TB ACTION] Writing 3 bytes into TX FIFO...");
        bus_write(ADDR_TDR, 8'hA5); // Byte 1
        bus_write(ADDR_TDR, 8'h5A); // Byte 2
        bus_write(ADDR_TDR, 8'h7D); // Byte 3
        
        // Step 4: Poll Status Register until SPI Core is no longer busy and RX FIFO is not empty
        // Status Register Bit 4 is 'spi_busy', Bit 2 is 'rx_empty'
        $display("[TB ACTION] Polling Status Register for transfer completion...");
        bus_read(ADDR_SR);
        while (bus_rdata[4] == 1'b1 || bus_rdata[2] == 1'b1) begin
            #40; // Wait 2 clock cycles before polling again
            bus_read(ADDR_SR);
        end
        $display("[REG CHECK] Transfer complete. Status Register: 8'b%b", bus_rdata);
        
        // Step 5: Read back the loopbacked data from the RX FIFO via RDR
        $display("[TB ACTION] Reading data back from RX FIFO...");
        
        bus_read(ADDR_RDR);
        $display("[DATA CHECK] Received Byte 1 (Expected A5): %h", bus_rdata);
        if (bus_rdata !== 8'hA5) $display("[FAILURE] Byte 1 mismatch!");

        bus_read(ADDR_RDR);
        $display("[DATA CHECK] Received Byte 2 (Expected 5A): %h", bus_rdata);
        if (bus_rdata !== 8'h5A) $display("[FAILURE] Byte 2 mismatch!");

        bus_read(ADDR_RDR);
        $display("[DATA CHECK] Received Byte 3 (Expected 7D): %h", bus_rdata);
        if (bus_rdata !== 8'h7D) $display("[FAILURE] Byte 3 mismatch!");

        // Step 6: Verify RX FIFO is now empty by checking Status Register again
        bus_read(ADDR_SR);
        if (bus_rdata[2] == 1'b1) begin
            $display("[SUCCESS] All bytes processed and verified. RX FIFO is successfully cleared.");
        end else begin
            $display("[FAILURE] Error: RX FIFO is not empty after reads.");
        end

        #100;
        $display("[TB INFO] --- Simulation Completed Safely ---");
        $finish;
    end

endmodule