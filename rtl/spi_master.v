`timescale 1ns / 1ps

module spi_master #(
    parameter [7:0] CLKS_PER_HALF_BIT = 8'd4
)(
    input  wire       clk,
    input  wire       rst_n,
    
    // Control from Register Map
    input  wire       spi_en,
    input  wire       cpol,
    input  wire       cpha,
    output reg        spi_busy,
    
    // Interface to TX FIFO
    input  wire [7:0] tx_data,
    input  wire       tx_empty,
    output reg        tx_rd_en,
    
    // Interface to RX FIFO
    output reg  [7:0] rx_data,
    output reg        rx_wr_en,
    
    // SPI Physical Interface
    output reg        sclk,
    output reg        mosi,
    input  wire       miso,
    output reg        cs_n
);

    localparam IDLE  = 2'b00;
    localparam SHIFT = 2'b01;
    localparam DONE  = 2'b10;
    
    reg [1:0] state;
    reg [7:0] tx_shift_reg;
    reg [7:0] rx_shift_reg;
    reg [2:0] bit_count;
    reg [7:0] clk_count;
    reg       sclk_en;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            sclk         <= 1'b0;
            mosi         <= 1'b0;
            cs_n         <= 1'b1;
            tx_rd_en     <= 1'b0;
            rx_wr_en     <= 1'b0;
            rx_data      <= 8'd0;
            spi_busy     <= 1'b0;
        end else begin
            tx_rd_en <= 1'b0;
            rx_wr_en <= 1'b0;
            
            // SCLK idles at CPOL
            if (!sclk_en) sclk <= cpol;
            
            case (state)
                IDLE: begin
                    cs_n     <= 1'b1;
                    spi_busy <= 1'b0;
                    sclk_en  <= 1'b0;
                    
                    if (spi_en && !tx_empty) begin
                        tx_shift_reg <= tx_data;
                        mosi         <= tx_data[7]; // preload MSB: must be valid before the first sclk edge (CPHA=0)
                        tx_rd_en     <= 1'b1;
                        spi_busy     <= 1'b1;
                        state        <= SHIFT;
                        bit_count    <= 3'd7;
                        clk_count    <= 8'd0;
                    end
                end
                
                SHIFT: begin
                    cs_n    <= 1'b0;
                    sclk_en <= 1'b1;
                    
                    if (clk_count == CLKS_PER_HALF_BIT - 8'd1) begin
                        clk_count <= 8'd0;
                        sclk      <= ~sclk;
                        
                        // Basic Phase Handling (simplified for readability)
                        // If CPHA=0: Sample on leading edge, shift on trailing
                        // If CPHA=1: Shift on leading edge, sample on trailing
                        if ((sclk == cpol && cpha == 0) || (sclk != cpol && cpha == 1)) begin
                            rx_shift_reg <= {rx_shift_reg[6:0], miso};
                            if (bit_count == 0) begin
                                state   <= DONE;
                                sclk_en <= 1'b0;
                            end else begin
                                bit_count <= bit_count - 1;
                            end
                        end else begin
                            mosi <= tx_shift_reg[bit_count];
                        end
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end
                
                DONE: begin
                    cs_n     <= 1'b1;
                    rx_data  <= rx_shift_reg;
                    rx_wr_en <= 1'b1;
                    state    <= IDLE;
                end

                default: begin
                    state    <= IDLE;
                    cs_n     <= 1'b1;
                    spi_busy <= 1'b0;
                    sclk_en  <= 1'b0;
                end
                
            endcase
        end
    end
endmodule
