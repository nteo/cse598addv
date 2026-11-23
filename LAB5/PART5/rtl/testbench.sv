module testbench;
  timeunit 1ns;
  timeprecision 1ps;

  logic clk, reset;
  logic [31:0] writedata, dataadr;
  logic memwrite;

  logic [31:0] machine_code_list [0:63];

  string  prog_file, trace_file;
  integer trace_fd;
  integer i;
  integer cycles;
  bit     done;

  string register_names [0:31] = '{
    "$zero", "$at", "$v0", "$v1",
    "$a0", "$a1", "$a2", "$a3",
    "$t0", "$t1", "$t2", "$t3",
    "$t4", "$t5", "$t6", "$t7",
    "$s0", "$s1", "$s2", "$s3",
    "$s4", "$s5", "$s6", "$s7",
    "$t8", "$t9", "$k0", "$k1",
    "$gp", "$sp", "$fp", "$ra"
  };

  top dut (
    .clk(clk),
    .reset(reset),
    .writedata(writedata),
    .dataadr(dataadr),
    .memwrite(memwrite)
  );

  task automatic copy_metadata(input string filename);
    integer metadata_fd;
    integer status;
    string line;

    metadata_fd = $fopen(filename, "r");

    if (metadata_fd == 0)
        $fatal(1, "ERROR: Could not open metadata file %s", filename);
    
    $display("Copying metadata from %s", filename);
   
    while (!$feof(metadata_fd)) begin
        status = $fgets(line, metadata_fd);
        if (status != 0)
            $fwrite(trace_fd, "%s", line);
    end

    $fclose(metadata_fd);
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    done = 0;

    if (!$value$plusargs("PROG=%s", prog_file))
      $fatal(1, "Missing +PROG=<binary machine code file>");

    if (!$value$plusargs("TRACE=%s", trace_file))
      trace_file = "rtl.trace";

    trace_fd = $fopen(trace_file, "w");
    if (trace_fd == 0)
      $fatal(1, "Could not open trace file %s", trace_file);

    copy_metadata("iss_metadata.txt");

    reset = 1;

    #1;
    for (i = 0; i < 64; i++)
      machine_code_list[i] = 32'h0;

    $readmemb(prog_file, machine_code_list);
    $writememh("rtl/memfile.dat", machine_code_list);
    $readmemh("rtl/memfile.dat", dut.imem.RAM);

    repeat (2) @(posedge clk);
    reset = 0;

    cycles = 0;
    while (dut.dmem.RAM[16'h0040 >> 2] !== 32'h0000_0DED
           && cycles < 5000) begin
      @(posedge clk);
      cycles++;
    end

    if (cycles >= 5000)
      $display("TIMEOUT: trickbox value never written");
    else
      $display("Trickbox written. Simulation ending after %0d cycles.", cycles);

    repeat (5) @(posedge clk);

    done = 1;
    $fclose(trace_fd);
    $finish;
  end

  // One trace entry per valid instruction reaching writeback.
  always @(posedge clk) begin
    if (!reset && !done && dut.mips.dp.validW === 1'b1) begin

      // Register dump header.
      $fdisplay(trace_fd, "Register values:");

      // Register dump contents.
      $fwrite(trace_fd, "");

      for (integer r = 0; r < 32; r++) begin
        if (r == 0)
          $fwrite(trace_fd, "%s: %0d",
                  register_names[r], 0);
        else
          $fwrite(trace_fd, "%s: %0d",
                  register_names[r], dut.mips.dp.rf.rf[r]);

        if (r != 31)
          $fwrite(trace_fd, " | ");
      end

      $fwrite(trace_fd, "\n");
      
      // Instruction execution line.
      $fdisplay(trace_fd, "Executing at 0x%h: %h",
                32'h40000000 + dut.mips.dp.pcW,
                dut.mips.dp.instrW);
    end
  end

  initial begin
    $fsdbDumpfile("novas.fsdb");
    $fsdbDumpvars(0, testbench);
    $fsdbDumpMDA(testbench.dut.dmem.RAM);
    $fsdbDumpMDA(testbench.dut.mips.dp.rf);
  end

endmodule
