// A replacement policy only matters if you have a choice of multiple cache lines that a block could go into.
// In a direct-mapped cache, each block of main memory maps to exactly one cache line.
module control_logic #(
    parameter DATA_WIDTH = 8, 
    parameter WRITE_POLICY = "WRITE_THROUGH"  // write through or write back
)(
    input  wire clk,
    input  wire reset,
    // CPU requests
    input  wire cpu_read,
    input  wire cpu_write,
    input  wire is_hit, // from comparator
    input  wire mem_ready, // handshake signal (operation requested done, data ready)
    input  wire [DATA_WIDTH-1:0] data_from_cache,
    input  wire [DATA_WIDTH-1:0] data_from_mem,
    input  wire dirty_out,   // dirty bit of selected cache line

    output reg  [DATA_WIDTH-1:0] data_out, // data sent back to cpu
    output reg  hit,
    output reg  miss,
    output reg  cache_write_en, //updates cache
    output reg  mem_write_en,
    output reg  mem_read_en,
    output reg  dirty_in,
    output reg  dirty_write_en
);

    // FSM states
    localparam S_IDLE           = 0, //waiting for cpu request
               S_COMPARE        = 1, //check for hit/miss
               S_READ_FETCH     = 2, //main memory read (on miss)
               S_READ_WAIT      = 3, // waiting for handshake signal from main memory
               S_READ_UPDATE    = 4, // fill cache with fetched block (cache replacement on miss)
               S_WRITE_BACK     = 5, //write back (WRITE-BACK policy)
               S_WRITE_THROUGH  = 6, // write through (WRITE-THROUGH policy)
               S_EVICT_WRITE    = 7, //Write dirty block to memory before replacement
               S_EVICT_WAIT = 8;

    reg [2:0] state, next_state;
    integer hit_count  = 0;
    integer miss_count = 0;

    // Sequential block
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // Combinational block
    always @(*) begin
        // Defaults
        next_state     = state;
        hit            = 0;
        miss           = 0;
        data_out       = 8'bx;
        cache_write_en = 0;
        mem_write_en   = 0;
        mem_read_en    = 0;
        dirty_in       = 0;
        dirty_write_en = 0;

        case (state)
            S_IDLE: begin
                if (cpu_read || cpu_write)
                    next_state = S_COMPARE;
            end

            S_COMPARE: begin
                if (cpu_read) begin
                    if (is_hit) begin
                        hit      = 1;
                        data_out = data_from_cache;
                        next_state = S_IDLE;
                    end else begin
                        miss = 1;
                        // If WRITE-BACK and current line is dirty → must write it back first
                        if ((WRITE_POLICY == "WRITE_BACK") && dirty_out)
                            next_state = S_EVICT_WRITE;
                        else
                            next_state = S_READ_FETCH;
                    end
                end else if (cpu_write) begin
                    if (WRITE_POLICY == "WRITE_BACK") begin
                        // 🟢 CHANGED: Write-Back + Write-Allocate
                        if (is_hit)
                            next_state = S_WRITE_BACK;         
                        else begin
                            miss = 1;
                            // if line dirty, evict first; then fetch new block for write-allocate
                            if (dirty_out)
                                next_state = S_EVICT_WRITE;    // 🟢 CHANGED
                            else
                                next_state = S_READ_FETCH;     // 🟢 CHANGED
                        end
                    end else begin
                        // 🟢 CHANGED: Write-Through + No-Write-Allocate
                        if (is_hit)
                            next_state = S_WRITE_THROUGH;      // cache + memory update
                        else begin
                            miss = 1;
                            // write directly to memory, do not allocate in cache
                            next_state = S_WRITE_THROUGH;      // 🟢 CHANGED
                        end
                    end
                end
            end

            // DIRTY WRITE-BACK (for eviction)
            S_EVICT_WRITE: begin
                mem_write_en   = 1;      
                dirty_in       = 0;      
                dirty_write_en = 1;
                next_state     = S_READ_FETCH;
            end
    
            S_EVICT_WRITE: begin
                mem_write_en   = 1;      
                dirty_in       = 0;      
                dirty_write_en = 1;
                next_state     = S_EVICT_WAIT; // 🟢 wait for handshake
            end

            S_EVICT_WAIT: begin
                mem_write_en = 1;
                if (mem_ready)
                    next_state = S_READ_FETCH; // safe to start reading new block
            end
            
            // READ MISS HANDLING
            S_READ_FETCH: begin
                mem_read_en = 1;
                next_state  = S_READ_WAIT;
            end

            S_READ_WAIT: begin
                mem_read_en = 1;
                if (mem_ready)
                    next_state = S_READ_UPDATE;
            end

            S_READ_UPDATE: begin
                // Fill cache with fetched block
                cache_write_en = 1;
                data_out       = data_from_mem;
                miss           = 1;

                // 🟢 FIX: If the original request was a WRITE, perform it now
                if (cpu_write && (WRITE_POLICY == "WRITE_BACK"))
                    next_state = S_WRITE_BACK;  // perform CPU write to the newly fetched line
                else
                    next_state = S_IDLE;
            end


            // WRITE HANDLING
            S_WRITE_BACK: begin
                // WRITE-BACK: update cache only, mark dirty
                cache_write_en = 1;
                dirty_in       = 1;
                dirty_write_en = 1;
                hit            = is_hit;
                miss           = !is_hit;
                next_state     = S_IDLE;
            end

            S_WRITE_THROUGH: begin
                // 🟢 CHANGED: Write-through + No-Write-Allocate
                // If hit: update cache and memory
                // If miss: update memory only (skip cache update)
                if (is_hit) begin
                    cache_write_en = 1;  // update cache line
                    mem_write_en   = 1;  // write to memory
                end else begin
                    mem_write_en   = 1;  // only memory write, skip cache
                end
                dirty_in       = 0;
                dirty_write_en = 1;
                next_state     = S_IDLE;
            end
        endcase
    end

    // Counters
    always @(posedge clk) begin
        if (hit)
            hit_count  <= hit_count + 1;
        if (miss)
            miss_count <= miss_count + 1;
    end

endmodule
