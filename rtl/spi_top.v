`timescale 1ns / 1ps

module spi_top (
    input  wire       clk,
    input  wire       rst_n,
    
    // Generic CPU/Bus Interface
    input  wire [1:0] bus_addr,
    input  wire [7:0] bus_wdata,
    input  wire       bus_wr_en,
    input  wire       bus_rd_en,
    output wire [7:0] bus_rdata,
    
    // SPI Physical Pins
    output wire       sclk,
    output wire       mosi,
    input  wire       miso,
    output wire       cs_n
);

    // Internal Connections
    wire       spi_en;
    wire       cpol;
    wire       cpha;
    wire       spi_busy;
    wire       tx_empty;
    wire       tx_full;
    wire       rx_empty;
    wire       rx_full;
    wire       tx_wr_en;
    wire [7:0] tx_wdata;
    wire       rx_rd_en;
    wire [7:0] rx_rdata;
    wire       spi_tx_rd_en;
    wire       spi_rx_wr_en;
    wire [7:0] tx_fifo_out;
    wire [7:0] spi_rx_data;

    // Register Map Instance
    spi_reg_map reg_map (
        .clk       (clk),
        .rst_n     (rst_n),
        .addr      (bus_addr),
        .wdata     (bus_wdata),
        .wr_en     (bus_wr_en),
        .rd_en     (bus_rd_en),
        .rdata     (bus_rdata),
        .spi_en    (spi_en),
        .cpol      (cpol),
        .cpha      (cpha),
        .tx_empty  (tx_empty),
        .tx_full   (tx_full),
        .rx_empty  (rx_empty),
        .rx_full   (rx_full),
        .spi_busy  (spi_busy),
        .tx_wr_en  (tx_wr_en),
        .tx_wdata  (tx_wdata),
        .rx_rd_en  (rx_rd_en),
        .rx_rdata  (rx_rdata)
    );

    // Transmit FIFO Instance
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH_LOG2(4)
    ) tx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (tx_wr_en),
        .wr_data (tx_wdata),
        .rd_en   (spi_tx_rd_en),
        .rd_data (tx_fifo_out),
        .empty   (tx_empty),
        .full    (tx_full)
    );

    // Receive FIFO Instance
    sync_fifo #(
        .DATA_WIDTH(8),
        .DEPTH_LOG2(4)
    ) rx_fifo (
        .clk     (clk),
        .rst_n   (rst_n),
        .wr_en   (spi_rx_wr_en),
        .wr_data (spi_rx_data),
        .rd_en   (rx_rd_en),
        .rd_data (rx_rdata),
        .empty   (rx_empty),
        .full    (rx_full)
    );

    // SPI Master Core Instance
    spi_master #(
        .CLKS_PER_HALF_BIT(8'd4)
    ) spi_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .spi_en   (spi_en),
        .cpol     (cpol),
        .cpha     (cpha),
        .spi_busy (spi_busy),
        .tx_data  (tx_fifo_out),
        .tx_empty (tx_empty),
        .tx_rd_en (spi_tx_rd_en),
        .rx_data  (spi_rx_data),
        .rx_wr_en (spi_rx_wr_en),
        .sclk     (sclk),
        .mosi     (mosi),
        .miso     (miso),
        .cs_n     (cs_n)
    );

endmodule