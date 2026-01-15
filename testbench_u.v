`timescale 1ns / 1ps

module tb_cache_dual_modes;

    localparam ADDRESS_WIDTH = 16;
    localparam DATA_WIDTH    = 8;
    localparam INDEX_WIDTH   = 8;

    reg clk;
    reg reset;

    reg [ADDRESS_WIDTH-1:0] addr;
    reg [DATA_WIDTH-1:0]    data_in;
    reg read;
    reg write;

    // Write-Through cache outputs
    wire [DATA_WIDTH-1:0] data_out_wt;
    wire hit_wt, miss_wt;

    // Write-Back cache outputs
    wire [DATA_WIDTH-1:0] data_out_wb;
    wire hit_wb, miss_wb;

    // Instantiate Write-Through (default) cache
    direct_mapped_cache #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .WRITE_POLICY("WRITE_THROUGH")
    ) cache_wt (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .data_in(data_in),
        .read(read),
        .write(write),
        .data_out(data_out_wt),
        .hit(hit_wt),
        .miss(miss_wt)
    );

    // Instantiate Write-Back cache
    direct_mapped_cache #(
        .ADDRESS_WIDTH(ADDRESS_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH),
        .WRITE_POLICY("WRITE_BACK")
    ) cache_wb (
        .clk(clk),
        .reset(reset),
        .addr(addr),
        .data_in(data_in),
        .read(read),
        .write(write),
        .data_out(data_out_wb),
        .hit(hit_wb),
        .miss(miss_wb)
    );

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Utility task: wait N cycles
    task wait_cycles;
        input integer cycles;
        begin
            repeat (cycles) @(posedge clk);
        end
    endtask

    // Task: CPU read
    task cpu_read;
        input [ADDRESS_WIDTH-1:0] r_addr;
        begin
            @(posedge clk);
            addr  <= r_addr;
            read  <= 1;
            write <= 0;
            wait_cycles(2); 
            read  <= 0;
            wait_cycles(2);
        end
    endtask

    // Task: CPU write
    task cpu_write;
        input [ADDRESS_WIDTH-1:0] w_addr;
        input [DATA_WIDTH-1:0] w_data;
        begin
            @(posedge clk);
            addr    <= w_addr;
            data_in <= w_data;
            read    <= 0;
            write   <= 1;
            wait_cycles(2);
            write   <= 0;
            wait_cycles(2);
        end
    endtask

    // Stimulus
    initial begin
        $dumpfile("cache_dual_wave.vcd");
        $dumpvars(0, tb_cache_dual_modes);

        reset   = 1;
        addr    = 0;
        data_in = 0;
        read    = 0;
        write   = 0;

        $display("\nTIME\tADDR  DATA_IN  READ    WRITE\t|    WT_HIT  WT_MISS    |    WB_HIT  WB_MISS");

        @(posedge clk);
        reset = 0;
        wait_cycles(3);

        // -------------------------------//
        // TEST 1: Basic write and read   //
        // -------------------------------//
        $display("\n--- TEST 1: Write then Read (0x1234 = 0xAA) ---");
        cpu_write(16'h1234, 8'hAA);
        cpu_read(16'h1234);

        // ----------------------------------//
        // TEST 2: Conflict (forces eviction)//
        // ----------------------------------//
        $display("\n--- TEST 2: Write 0x1234 (dirty), then read 0x9234 (same index) ---");
        cpu_write(16'h1234, 8'hCC);
        cpu_read(16'h9234);

        // -------------------------------//
        // TEST 3: Re-read old address    //
        // -------------------------------//
        $display("\n--- TEST 3: Read 0x1234 again ---");
        cpu_read(16'h1234);

        // -------------------------------//
        // TEST 4: Sequential hits        //
        // -------------------------------//
        $display("\n--- TEST 4: Repeated hits on same address ---");
        cpu_read(16'h1234);
        cpu_read(16'h1234);
        cpu_read(16'h1234);

        // -------------------------------//
        // TEST 5: Fresh miss             //
        // -------------------------------//
        $display("\n--- TEST 5: New address miss ---");
        cpu_read(16'hB333);

        wait_cycles(10);
        $display("\n--- Simulation complete ---");
        $stop;
    end

    // Display signals continuously :-
    always @(posedge clk) begin
        $display("%0t\t%h\t%h\t%b\t%b\t|\t%b\t%b\t|\t%b\t%b",
                 $time, addr, data_in, read, write,
                 hit_wt, miss_wt, hit_wb, miss_wb);
    end

    initial begin
        wait(reset == 0);
        wait_cycles(300);
        $display("\n--- Simulation Summary ---");
        $display("WRITE-THROUGH  : Hits=%0d Misses=%0d", cache_wt.fsm.hit_count, cache_wt.fsm.miss_count);
        $display("WRITE-BACK     : Hits=%0d Misses=%0d", cache_wb.fsm.hit_count, cache_wb.fsm.miss_count);
        $finish;
    end

endmodule
