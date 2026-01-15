module direct_mapped_cache #(
    parameter ADDRESS_WIDTH = 16,
    parameter DATA_WIDTH    = 8,
    parameter INDEX_WIDTH   = 8,
    parameter WRITE_POLICY  = "WRITE_THROUGH"
)(
    input wire clk,
    input wire reset,
    input wire [ADDRESS_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire read,
    input wire write,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire hit,
    output wire miss
);

    localparam TAG_WIDTH = ADDRESS_WIDTH - INDEX_WIDTH;
    localparam CACHE_DEPTH = 1 << INDEX_WIDTH;

    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;

    wire [TAG_WIDTH-1:0] cache_tag_out;
    wire [DATA_WIDTH-1:0] cache_data_out;
    wire cache_valid_out;
    wire cache_dirty_out;
    wire cache_write_en;

    wire [DATA_WIDTH-1:0] mem_data_out;
    wire [DATA_WIDTH-1:0] mem_data_in;   // 🟢 added
    wire mem_ready;
    wire mem_write_en;
    wire mem_read_en;

    wire is_hit;
    wire dirty_in;          // 🟢 added
    wire dirty_write_en;    // 🟢 added

    reg [ADDRESS_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] data_in_reg;
    reg read_reg, write_reg;

    assign index = addr_reg[INDEX_WIDTH-1:0];
    assign tag   = addr_reg[ADDRESS_WIDTH-1:INDEX_WIDTH];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_reg  <= 0;
            write_reg <= 0;
        end else begin
            addr_reg  <= addr;
            data_in_reg <= data_in;
            write_reg <= write;
            read_reg  <= read & ~write;
        end
    end

    // 🟢 Mux for main memory input (CPU data vs dirty cache line)
    assign mem_data_in =
    (mem_write_en && !mem_read_en && WRITE_POLICY == "WRITE_BACK") ? cache_data_out : data_in_reg;


    // 🟢 Cache input data selection (memory data for fill, CPU data otherwise)
    wire [DATA_WIDTH-1:0] cache_write_data =
    (fsm.state == fsm.S_READ_UPDATE) ? mem_data_out : data_in_reg;


    cache_memory_array #(
        .CACHE_DEPTH(CACHE_DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TAG_WIDTH(TAG_WIDTH)
    ) cache_mem (
        .clk(clk),
        .reset(reset),
        .index(index),
        .tag_in(tag),
        .data_in(cache_write_data),
        .write_en(cache_write_en),
        .dirty_in(dirty_in),
        .dirty_write_en(dirty_write_en),
        .tag_out(cache_tag_out),
        .data_out(cache_data_out),
        .valid_out(cache_valid_out),
        .dirty_out(cache_dirty_out)
    );

    main_memory #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) main_mem (
        .clk(clk),
        .addr(addr_reg),
        .data_in(mem_data_in),
        .write_en(mem_write_en),
        .read_en(mem_read_en),
        .data_out(mem_data_out),
        .ready(mem_ready)
    );

    comparator_logic #(
        .TAG_WIDTH(TAG_WIDTH)
    ) comparator (
        .tag_cpu(tag),
        .tag_cache(cache_tag_out),
        .valid_in(cache_valid_out),
        .is_hit(is_hit)
    );

    control_logic #(
        .DATA_WIDTH(DATA_WIDTH),
        .WRITE_POLICY(WRITE_POLICY)
    ) fsm (
        .clk(clk),
        .reset(reset),
        .cpu_read(read_reg),
        .cpu_write(write_reg),
        .is_hit(is_hit),
        .mem_ready(mem_ready),
        .data_from_cache(cache_data_out),
        .data_from_mem(mem_data_out),
        .dirty_out(cache_dirty_out),      // 🟢 added connection
        .data_out(data_out),
        .hit(hit),
        .miss(miss),
        .cache_write_en(cache_write_en),
        .mem_write_en(mem_write_en),
        .mem_read_en(mem_read_en),
        .dirty_in(dirty_in),
        .dirty_write_en(dirty_write_en)
    );

endmodule
