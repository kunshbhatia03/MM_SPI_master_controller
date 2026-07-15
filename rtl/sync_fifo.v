`timescale 1ns / 1ps

module sync_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH_LOG2 = 4 // Depth = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // Write interface
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    
    // Read interface
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data, // FIX: Changed from reg to wire for FWFT
    
    // Status flags
    output wire                  empty,
    output wire                  full
);

    localparam DEPTH = 1 << DEPTH_LOG2;
    
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DEPTH_LOG2:0]   count;
    reg [DEPTH_LOG2-1:0] wr_ptr;
    reg [DEPTH_LOG2-1:0] rd_ptr;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);
    
    // FIX: Continuous assignment allows data to be visible instantly (FWFT)
    assign rd_data = mem[rd_ptr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr  <= 0;
            rd_ptr  <= 0;
            count   <= 0;
        end else begin
            // Write operation
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1;
            end
            
            // Read operation
            if (rd_en && !empty) begin
                rd_ptr  <= rd_ptr + 1;
            end
            
            // Count management
            if ((wr_en && !full) && !(rd_en && !empty))
                count <= count + 1;
            else if (!(wr_en && !full) && (rd_en && !empty))
                count <= count - 1;
        end
    end
endmodule
