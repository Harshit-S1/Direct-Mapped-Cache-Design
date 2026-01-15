module comparator_logic #(
    parameter TAG_WIDTH = 8
) (
    input wire [TAG_WIDTH-1:0] tag_cpu, // tag requested by the cpu
    input wire [TAG_WIDTH-1:0] tag_cache, // tag in the cache line
    input wire valid_in,
    output wire is_hit
);

    assign is_hit = (tag_cpu == tag_cache) && valid_in; // hit only when tag present and cpu and cache tag match

endmodule