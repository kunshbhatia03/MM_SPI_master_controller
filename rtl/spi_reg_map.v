`timescale 1ns / 1ps

// Memory-mapped register interface
module spi_reg_map (
    input  wire       clk,
    input  wire       rst_n,
    
    // Generic Bus Interface
    input  wire [1:0] addr,
    input  wire [7:0] wdata,
    input  wire       wr_en,
    input  wire       rd_en,
    output reg  [7:0] rdata,
    
    // Control & Status Signals to/from Hardware
    output reg        spi_en,
    output reg        cpol,
    output reg        cpha,
    
    input  wire       tx_empty,
    input  wire       tx_full,
    input  wire       rx_empty,
    input  wire       rx_full,
    input  wire       spi_busy,
    
    // FIFO Interfaces
    output reg        tx_wr_en,
    output reg  [7:0] tx_wdata,
    output reg        rx_rd_en,
    input  wire [7:0] rx_rdata
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spi_en   <= 1'b0;
            cpol     <= 1'b0;
            cpha     <= 1'b0;
            tx_wr_en <= 1'b0;
            rx_rd_en <= 1'b0;
            tx_wdata <= 8'd0;
            rdata    <= 8'd0;
        end else begin
            // Default FIFO strobes (single cycle pulse)
            tx_wr_en <= 1'b0;
            rx_rd_en <= 1'b0;
            
            // Bus Write Operations
            if (wr_en) begin
                case (addr)
                    2'b00: begin // CR
                        spi_en <= wdata[0];
                        cpol   <= wdata[1];
                        cpha   <= wdata[2];
                    end
                    2'b10: begin // TDR
                        if (!tx_full) begin
                            tx_wdata <= wdata;
                            tx_wr_en <= 1'b1;
                        end
                    end
                    default: ; // SR and RDR are read-only
                endcase
            end
            
            // Bus Read Operations
            if (rd_en) begin
                case (addr)
                    2'b00: rdata <= {5'd0, cpha, cpol, spi_en}; // CR
                    2'b01: rdata <= {3'd0, spi_busy, rx_full, rx_empty, tx_full, tx_empty}; // SR
                    2'b11: begin // RDR
                        if (!rx_empty) begin
                            rdata    <= rx_rdata;
                            rx_rd_en <= 1'b1; // Pop FIFO on read
                        end else begin
                            rdata <= 8'd0;
                        end
                    end
                    default: rdata <= 8'd0;
                endcase
            end
        end
    end
endmodule
