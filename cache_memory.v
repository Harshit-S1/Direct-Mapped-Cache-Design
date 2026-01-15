module cache_memory_array #(
    parameter CACHE_DEPTH = 256,
    parameter DATA_WIDTH = 8,
    parameter TAG_WIDTH = 8
) (
    input wire clk,
    input wire reset,
    input wire [($clog2(CACHE_DEPTH))-1:0] index,
    input wire [TAG_WIDTH-1:0] tag_in,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire write_en,
    input wire dirty_in,
    input wire dirty_write_en,
    output wire [TAG_WIDTH-1:0] tag_out,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire valid_out,
    output wire dirty_out
);

    integer i;
    reg [TAG_WIDTH-1:0] tag_array [0:CACHE_DEPTH-1];
    reg [DATA_WIDTH-1:0] data_array [0:CACHE_DEPTH-1];
    reg valid_array [0:CACHE_DEPTH-1];
    reg dirty_array [0:CACHE_DEPTH-1];

    assign tag_out = tag_array[index];
    assign data_out = data_array[index];
    assign valid_out = valid_array[index];
    assign dirty_out = dirty_array[index];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < CACHE_DEPTH; i = i + 1) begin
                valid_array[i] <= 0;
                tag_array[i] <= 0;
                data_array[i] <= 0;
                dirty_array[i] <= 0;
            end
        end else begin
            if (write_en) begin
                tag_array[index] <= tag_in;
                data_array[index] <= data_in;
                valid_array[index] <= 1;
            end
            if (dirty_write_en)
                dirty_array[index] <= dirty_in;
        end
    end
endmodule
