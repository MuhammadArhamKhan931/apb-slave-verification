`timescale 1ns/1ps
 
interface apb_if (input logic PCLK, input logic PRESETn);
 
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [7:0]  PADDR;
    logic [31:0] PWDATA;
    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;
 
    modport driver (
        input  PCLK, input PRESETn,
        output PSEL, output PENABLE, output PWRITE,
        output PADDR, output PWDATA,
        input  PRDATA, input PREADY, input PSLVERR
    );
 
    modport monitor (
        input PCLK, input PRESETn,
        input PSEL, input PENABLE, input PWRITE,
        input PADDR, input PWDATA,
        input PRDATA, input PREADY, input PSLVERR
    );
 
    modport dut (
        input  PCLK, input PRESETn,
        input  PSEL, input PENABLE, input PWRITE,
        input  PADDR, input PWDATA,
        output PRDATA, output PREADY, output PSLVERR
    );
 
endinterface
 
class transaction;
    rand bit [7:0]  addr;
    rand bit [31:0] wdata;
    rand bit        write;
 
    bit [31:0] rdata;
 
    constraint c_write_dist {
        write dist { 0 := 50, 1 := 50 };
    }
 
    constraint c_wdata_dist {
        wdata dist {
            32'h00000000               := 8,
            [32'h00000001:32'h0000FFFF] := 22,
            [32'h00010000:32'hFFFFFFFF] := 70
        };
    }
 
    function transaction copy();
        transaction t = new();
        t.addr  = this.addr;
        t.wdata = this.wdata;
        t.write = this.write;
        t.rdata = this.rdata;
        return t;
    endfunction
 
    function void display(string tag);
        if (write)
            $display("[%0t] %s WRITE addr=%0d data=%0h", $time, tag, addr, wdata);
        else
            $display("[%0t] %s READ  addr=%0d data=%0h", $time, tag, addr, rdata);
    endfunction
endclass
 
class coverage;
 
    bit        pwrite;
    bit [7:0]  paddr;
    bit [31:0] pwdata;
    bit        pready;
    bit        pslverr;
 
    covergroup cg;
        option.per_instance = 1;
 
        cp_write: coverpoint pwrite {
            bins read  = {0};
            bins write = {1};
        }
 
        cp_addr: coverpoint paddr {
            bins low    = {[0:63]};
            bins middle = {[64:127]};
            bins high   = {[128:191]};
            bins upper  = {[192:255]};
        }
 
        cp_wdata: coverpoint pwdata {
            bins zero        = {32'h00000000};
            bins small_val    = {[32'h00000001:32'h0000FFFF]};
            bins default_bin = default;
        }
 
        cp_ready: coverpoint pready {
            bins wait_state = {0};
            bins ready      = {1};
        }
 
        cx_write_addr:  cross cp_write, cp_addr;
        cx_write_ready: cross cp_write, cp_ready;
        cx_addr_ready:  cross cp_addr,  cp_ready;
 
    endgroup
 
    covergroup cg_err;
        option.per_instance = 1;
        cp_err: coverpoint pslverr {
            bins no_error = {0};
            bins error    = {1};
        }
    endgroup
 
    function new();
        cg     = new();
        cg_err = new();
    endfunction
 
    function void sample(bit write, bit [7:0] addr, bit [31:0] wdata, bit ready, bit slverr);
        this.pwrite  = write;
        this.paddr   = addr;
        this.pwdata  = wdata;
        this.pready  = ready;
        this.pslverr = slverr;
        cg.sample();
        cg_err.sample();
    endfunction
 
    function void report();
        $display("---- FUNCTIONAL COVERAGE REPORT ----");
        $display("cp_write        : %0.2f%%", cg.cp_write.get_coverage());
        $display("cp_addr         : %0.2f%%", cg.cp_addr.get_coverage());
        $display("cp_wdata        : %0.2f%%", cg.cp_wdata.get_coverage());
        $display("cp_ready        : %0.2f%%", cg.cp_ready.get_coverage());
        $display("cp_err          : %0.2f%%  (0xFF reserved-address access - kept out of TOTAL by design)", cg_err.cp_err.get_coverage());
        $display("cx_write_addr   : %0.2f%%", cg.cx_write_addr.get_coverage());
        $display("cx_write_ready  : %0.2f%%", cg.cx_write_ready.get_coverage());
        $display("cx_addr_ready   : %0.2f%%", cg.cx_addr_ready.get_coverage());
        $display("TOTAL           : %0.2f%%", cg.get_coverage());
    endfunction
endclass
 
class generator;
    mailbox #(transaction) gen2drv;
    int num_random;
 
    function new(mailbox #(transaction) gen2drv, int num_random = 60);
        this.gen2drv   = gen2drv;
        this.num_random = num_random;
    endfunction
 
    task send(bit [7:0] addr, bit [31:0] wdata, bit write);
        transaction t = new();
        t.addr = addr; t.wdata = wdata; t.write = write;
        gen2drv.put(t);
    endtask
 
    task run();
        send(8'h10, 32'h0, 1'b0);
        send(8'h20, 32'hDEAD_BEEF, 1'b1);
        send(8'd100, 32'h0, 1'b0);
        send(8'd150, 32'hCAFE_1234, 1'b1);
        send(8'd30, 32'h00000000, 1'b1);
        send(8'd35, 32'h0000_ABCD, 1'b1);
        send(8'd31, 32'h1234_5678, 1'b1);
        send(8'd40, 32'h0, 1'b0);
        send(8'd41, 32'h0, 1'b0);
        send(8'd42, 32'h0, 1'b0);
        send(8'd50, 32'hAAAA_AAAA, 1'b1);
        send(8'd51, 32'hBBBB_BBBB, 1'b1);
        send(8'd52, 32'hCCCC_CCCC, 1'b1);
        send(8'hFF, 32'hFACE_FEED, 1'b1);
 
        $display("[%0t] GENERATOR: done issuing 14 directed cases", $time);
 
        for (int i = 0; i < num_random; i++) begin
            transaction t = new();
            if (!t.randomize())
                $display("GENERATOR: randomize() failed for random[%0d]", i);
            gen2drv.put(t);
        end
 
        $display("[%0t] GENERATOR: done issuing %0d random cases", $time, num_random);
    endtask
endclass
 
class driver;
    virtual apb_if.driver vif;
    mailbox #(transaction) gen2drv;
 
    function new(virtual apb_if.driver vif, mailbox #(transaction) gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction
 
    task run();
        transaction t;
        forever begin
            gen2drv.get(t);
            drive_one(t);
        end
    endtask
 
    task drive_one(transaction t);
        @(posedge vif.PCLK);
        vif.PADDR   <= t.addr;
        vif.PWDATA  <= t.wdata;
        vif.PWRITE  <= t.write;
        vif.PSEL    <= 1'b1;
        vif.PENABLE <= 1'b0;
 
        @(posedge vif.PCLK);
        vif.PENABLE <= 1'b1;
 
        @(posedge vif.PCLK);
        while (!vif.PREADY) @(posedge vif.PCLK);
 
        if (!t.write)
            t.rdata = vif.PRDATA;
 
        t.display("DRV");
 
        vif.PSEL    <= 1'b0;
        vif.PENABLE <= 1'b0;
    endtask
endclass
 
class monitor;
    virtual apb_if.monitor vif;
    mailbox #(transaction) mon2scb;
    coverage cov;
 
    int completed = 0;
 
    function new(virtual apb_if.monitor vif, mailbox #(transaction) mon2scb, coverage cov);
        this.vif     = vif;
        this.mon2scb = mon2scb;
        this.cov     = cov;
    endfunction
 
    task run();
        transaction t;
        forever begin
            @(posedge vif.PCLK);
            if (vif.PSEL && vif.PENABLE) begin
                cov.sample(vif.PWRITE, vif.PADDR, vif.PWDATA, vif.PREADY, vif.PSLVERR);
 
                if (vif.PREADY) begin
                    completed++;
                    if (!vif.PSLVERR) begin
                        t = new();
                        t.addr  = vif.PADDR;
                        t.write = vif.PWRITE;
                        t.wdata = vif.PWDATA;
                        t.rdata = vif.PRDATA;
                        mon2scb.put(t);
                    end
                end
            end
        end
    endtask
endclass
 
class scoreboard;
    mailbox #(transaction) mon2scb;
    bit [31:0] shadow_mem [0:255];
    int error_count = 0;
    int match_count = 0;
 
    function new(mailbox #(transaction) mon2scb);
        this.mon2scb = mon2scb;
        foreach (shadow_mem[i]) shadow_mem[i] = 32'h0;
    endfunction
 
    task run();
        transaction t;
        forever begin
            mon2scb.get(t);
            if (t.write) begin
                shadow_mem[t.addr] = t.wdata;
                match_count++;
            end else begin
                if (t.rdata !== shadow_mem[t.addr]) begin
                    $display("*** SCB MISMATCH *** addr=%0d exp=%0h got=%0h",
                              t.addr, shadow_mem[t.addr], t.rdata);
                    error_count++;
                end else begin
                    match_count++;
                end
            end
        end
    endtask
 
    function void report();
        $display("---- SCOREBOARD REPORT ----");
        $display("Matches : %0d", match_count);
        $display("Errors  : %0d", error_count);
    endfunction
endclass
 
class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;
    coverage   cov;
 
    mailbox #(transaction) gen2drv;
    mailbox #(transaction) mon2scb;
 
    int num_random = 60;
    int total;
 
    function new(virtual apb_if vif);
        total = 14 + num_random;
 
        gen2drv = new();
        mon2scb = new();
        cov     = new();
 
        gen = new(gen2drv, num_random);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb, cov);
        scb = new(mon2scb);
    endfunction
 
    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
 
        wait (mon.completed == total);
        #50;
        scb.report();
        cov.report();
    endtask
endclass
 
class test;
    environment env;
 
    function new(virtual apb_if vif);
        env = new(vif);
    endfunction
 
    task run();
        env.run();
    endtask
endclass
 
module top_tb;
 
    logic PCLK;
    logic PRESETn;
 
    apb_if vif (PCLK, PRESETn);
 
    apb_slave_dut_cov dut (
        .PCLK    (vif.PCLK),
        .PRESETn (vif.PRESETn),
        .PSEL    (vif.PSEL),
        .PENABLE (vif.PENABLE),
        .PWRITE  (vif.PWRITE),
        .PADDR   (vif.PADDR),
        .PWDATA  (vif.PWDATA),
        .PRDATA  (vif.PRDATA),
        .PREADY  (vif.PREADY),
        .PSLVERR (vif.PSLVERR)
    );
 
    initial PCLK = 1'b0;
    always #5 PCLK = ~PCLK;
 
    initial begin
        PRESETn = 1'b0;
        #20 PRESETn = 1'b1;
    end
 
    test t;
 
    initial begin
        @(posedge PRESETn);
        t = new(vif);
        t.run();
        #100;
        $finish;
    end
 
endmodule
 
