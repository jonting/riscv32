`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Created by:
//   Md Badruddoja Majumder, Garrett S. Rose
//   University of Tennessee, Knoxville
//
// Created:
//   October 30, 2018
//
// Module name: RISCVcore
// Description:
//   Implements top Mini-RISC-V core logic
//
// "Mini-RISC-V" implementation of RISC-V architecture developed by UC Berkeley
//
// Inputs:
//   clk -- system clock
//   Rst -- system reset signal
//   debug -- 1-bit debug control signal
//   debug_input -- 5-bit register address for viewing via debug port
// Output:
//   debug_output -- 32-bit output port for viewing contents of register
//
//////////////////////////////////////////////////////////////////////////////////

//Interface bus between all pipeline stages
interface main_bus_if (
    input logic clk,
    input logic Rst,
    input logic debug,
    input logic dbg,
    input logic prog,
    input logic mem_hold,
    input logic uart_IRQ,
    input logic RAS_rdy,
    input logic [4:0] debug_input
);

  logic        PC_En;
  logic        hz;
  logic        branch;
  logic [31:0] branoff;
  logic [31:0] ID_EX_pres_addr;
  logic [31:0] ins;
  logic [ 4:0] ID_EX_rd;
  logic ID_EX_memread, ID_EX_regwrite;
  logic [4:0] EX_MEM_rd, MEM_WB_rd, WB_ID_rd;
  logic [4:0] ID_EX_rs1, ID_EX_rs2, ID_EX_rs3;
  logic [31:0] ID_EX_dout_rs1, ID_EX_dout_rs2, ID_EX_dout_rs3, EX_MEM_dout_rs2;
  logic [31:0] IF_ID_dout_rs1, IF_ID_dout_rs2, IF_ID_dout_rs3;
  logic [31:0] IF_ID_pres_addr;
  logic        IF_ID_jalr;
  logic ID_EX_jal, ID_EX_jalr;
  logic ID_EX_compare;
  logic [31:0] EX_MEM_alures, MEM_WB_alures, MEM_WB_memres;
  logic [31:0] EX_MEM_mulres, MEM_WB_mulres;
  logic EX_MEM_mulvalid;
  logic [31:0] EX_MEM_divres, MEM_WB_divres;
  logic        EX_MEM_divvalid;
  logic        EX_MEM_comp_res;

  logic [31:0] EX_MEM_pres_addr;
  logic [31:0] MEM_WB_pres_addr;

  logic [4:0] EX_MEM_rs1, EX_MEM_rs2;

  logic [2:0] ID_EX_alusel, ID_EX_frm, EX_MEM_frm;
  logic [2:0] ID_EX_mulsel;
  logic [2:0] ID_EX_divsel;
  logic [4:0] ID_EX_fpusel;
  logic [4:0] ID_EX_loadcntrl;
  logic [2:0] ID_EX_storecntrl;
  logic [3:0] ID_EX_cmpcntrl;
  logic [4:0] EX_MEM_loadcntrl;
  logic [2:0] EX_MEM_storecntrl;
  logic ID_EX_alusrc, IF_ID_fpusrc, ID_EX_fpusrc, EX_MEM_fpusrc, MEM_WB_fpusrc, WB_ID_fpusrc;
  logic EX_MEM_memread, MEM_WB_memread;
  logic ID_EX_memwrite, EX_MEM_memwrite;
  logic EX_MEM_regwrite, MEM_WB_regwrite, WB_ID_regwrite;
  logic        ID_EX_lui;
  logic        ID_EX_auipc;
  logic [31:0] ID_EX_imm;
  logic [31:0] WB_res, WB_ID_res;
  logic [4:0] adr_rs1;  //used for debug option
  logic [4:0] IF_ID_rs1, IF_ID_rs2, IF_ID_rs3, IF_ID_rd;
  logic ID_EX_lb, ID_EX_lh, ID_EX_lw, ID_EX_lbu, ID_EX_lhu, ID_EX_sb, ID_EX_sh, ID_EX_sw;
  logic EX_MEM_lb, EX_MEM_lh, EX_MEM_lw, EX_MEM_lbu, EX_MEM_lhu, EX_MEM_sb, EX_MEM_sh, EX_MEM_sw;
  logic        f_stall;  //used for stall the pipe for floating point calculation.
  logic [31:0] uart_dout;
  logic        memcon_prog_ena;

  logic        IF_ID_jal;

  logic        mmio_wea;
  logic [31:0] mmio_dat;
  logic        mmio_read;

  logic [31:0] DD_out;

  logic [31:0] mem_din, mem_dout;
  logic [31:0] mem_addr;
  logic [3:0] mem_en;
  logic mem_wea;
  logic mem_rea;

  logic [31:0] imem_dout;
  logic imem_en;
  logic [31:0] imem_addr;

  logic mul_ready;
  logic EX_MEM_mul_ready, MEM_WB_mul_ready;
  logic div_ready;
  logic EX_MEM_div_ready, MEM_WB_div_ready;

  logic comp_sig;
  logic ID_EX_comp_sig;


  //CSR signals
  logic [11:0] IF_ID_CSR_addr, ID_EX_CSR_addr;
  logic [31:0] IF_ID_CSR, ID_EX_CSR;
  logic [31:0] EX_CSR_res;
  logic [31:0] EX_MEM_CSR, MEM_WB_CSR;
  logic [11:0] EX_CSR_addr;
  logic ID_EX_CSR_write;
  logic EX_CSR_write;
  logic MEM_WB_CSR_write;
  logic ID_EX_CSR_read, EX_MEM_CSR_read, MEM_WB_CSR_read;

  logic [2:0] csrsel;

  logic trap, ecall;
  logic [31:0] mtvec, mepc;

  logic trapping, trigger_trap, trap_ret, trigger_trap_ret;

  logic [31:0] next_addr;


  assign trap = ecall;
  always_ff @(posedge clk) begin
    if (Rst) begin
      trapping <= 0;
      trigger_trap <= 0;
      trigger_trap_ret <= 0;
    end else begin
      if (trap & (~trapping)) begin
        trapping <= 1;
        trigger_trap <= 1;
      end else trigger_trap <= 0;

      if (trap_ret & (trapping)) begin
        trapping <= 0;
        trigger_trap_ret <= 1;
      end else trigger_trap_ret <= 0;
    end
  end


  //photon_core signals
  logic [31:0] photon_ins, photon_data_out;
  logic photon_busy, photon_regwrite;
  logic [4:0] adr_photon_rs1, addr_corereg_photon;

  //modport declarations. These ensure each pipeline stage only sees and has access to the
  //ports and signals that it needs



  //modport for fetch stage
  modport fetch(
      input clk, PC_En, debug, prog, Rst, branch,
      input trap, mtvec, mepc, trigger_trap, trap_ret, trigger_trap_ret,
      input uart_dout, memcon_prog_ena,
      input debug_input, branoff,
      input imem_dout,
      input dbg, mem_hold, f_stall,
      input IF_ID_jalr, IF_ID_jal,
      output ins, imem_en, imem_addr, comp_sig, next_addr,
      output IF_ID_pres_addr
  );

  //modport for register file
  modport regfile(
      input clk, adr_rs1, adr_photon_rs1, addr_corereg_photon, Rst, f_stall,
      input mem_hold, photon_data_out, photon_regwrite,
      input IF_ID_rs1, IF_ID_rs2, IF_ID_rs3, IF_ID_fpusrc,
      input MEM_WB_rd, MEM_WB_regwrite, MEM_WB_fpusrc,
      input WB_res,
      output IF_ID_dout_rs1, IF_ID_dout_rs2, IF_ID_dout_rs3
  );

  //modport for decode stage
  modport decode(
      input clk, Rst, dbg, ins, mem_hold, comp_sig, f_stall,
      input mul_ready, div_ready,
      input trap, trigger_trap, RAS_rdy,
      input IF_ID_pres_addr, IF_ID_dout_rs1, IF_ID_dout_rs2, IF_ID_dout_rs3, IF_ID_CSR,
      input EX_MEM_memread, EX_MEM_regwrite, EX_MEM_alures, EX_MEM_divres, EX_MEM_mulres, EX_MEM_rd,
      input MEM_WB_rd, MEM_WB_regwrite,
      input WB_res,
      output branch, branoff, hz,
      output csrsel, ecall, trap_ret,
      output IF_ID_fpusrc, IF_ID_jalr, IF_ID_jal, IF_ID_rs1, IF_ID_rs2, IF_ID_rs3, IF_ID_rd,
      output IF_ID_CSR_addr,
      output ID_EX_memread, ID_EX_regwrite, ID_EX_pres_addr, ID_EX_jalr,
      output ID_EX_dout_rs1, ID_EX_dout_rs2, ID_EX_rs1, ID_EX_rs2, ID_EX_rs3, ID_EX_rd,
      output ID_EX_alusel, ID_EX_fpusel, ID_EX_frm,
      output ID_EX_storecntrl, ID_EX_loadcntrl, ID_EX_cmpcntrl,
      output ID_EX_auipc, ID_EX_lui, ID_EX_alusrc, ID_EX_fpusrc,
      output ID_EX_memwrite, ID_EX_imm, ID_EX_compare, ID_EX_jal,
      output ID_EX_CSR_addr, ID_EX_CSR, ID_EX_CSR_write, ID_EX_CSR_read, ID_EX_comp_sig,
      output ID_EX_mulsel, ID_EX_divsel
  );

  //modport for execute stage
  modport execute(
      input clk, Rst, dbg, mem_hold, f_stall, csrsel,
      input ID_EX_lui, ID_EX_auipc, ID_EX_loadcntrl,
      input ID_EX_storecntrl, ID_EX_cmpcntrl,
      input ID_EX_compare, ID_EX_pres_addr, ID_EX_alusel, ID_EX_alusrc,
      input ID_EX_fpusel, ID_EX_fpusrc, ID_EX_frm,
      input ID_EX_mulsel, ID_EX_divsel,
      input ID_EX_memread, ID_EX_memwrite, ID_EX_regwrite, ID_EX_jal,
      input ID_EX_jalr, ID_EX_rs1, ID_EX_rs2, ID_EX_rs3, ID_EX_rd,
      input ID_EX_dout_rs1, ID_EX_dout_rs2, ID_EX_dout_rs3,
      input ID_EX_imm,
      input ID_EX_CSR_addr, ID_EX_CSR, ID_EX_CSR_write, ID_EX_CSR_read,
      input ID_EX_comp_sig,
      input MEM_WB_regwrite, MEM_WB_rd,
      input WB_res, WB_ID_regwrite, WB_ID_res, WB_ID_rd,
      output mul_ready, div_ready,
      output EX_MEM_loadcntrl, EX_MEM_storecntrl,
      output EX_MEM_dout_rs2, EX_MEM_rs2, EX_MEM_rs1,
      output EX_MEM_alures,
      output EX_MEM_memread, EX_MEM_rd,
      output EX_MEM_memwrite, EX_MEM_regwrite, EX_MEM_comp_res, EX_MEM_fpusrc, EX_MEM_frm,
      output EX_MEM_pres_addr,
      output EX_CSR_res, EX_CSR_addr, EX_CSR_write, EX_MEM_CSR, EX_MEM_CSR_read,
      output EX_MEM_mul_ready, EX_MEM_div_ready,
      output EX_MEM_mulres, EX_MEM_divres
  );

  //modport for memory stage
  modport memory(
      input clk, Rst, dbg, mmio_read, mem_hold, f_stall,
      input EX_MEM_storecntrl, EX_MEM_pres_addr, EX_MEM_fpusrc,
      input EX_MEM_loadcntrl, EX_MEM_alures, EX_MEM_dout_rs2, EX_MEM_rs2, EX_MEM_rs1,
      input EX_MEM_rd, EX_MEM_regwrite, EX_MEM_memread, EX_MEM_memwrite,
      input WB_res,
      output mmio_wea, mmio_dat,
      output MEM_WB_regwrite, MEM_WB_memread, MEM_WB_rd,
      output MEM_WB_alures, MEM_WB_memres, MEM_WB_fpusrc,

      input mem_dout,
      output mem_din, mem_addr, mem_wea, mem_en, mem_rea,
      output MEM_WB_pres_addr,

      input EX_MEM_CSR, EX_MEM_CSR_read,
      output MEM_WB_CSR, MEM_WB_CSR_read,

      input EX_MEM_mul_ready, EX_MEM_div_ready,
      input EX_MEM_mulres, EX_MEM_divres,
      output MEM_WB_mul_ready, MEM_WB_div_ready,
      output MEM_WB_mulres, MEM_WB_divres
  );

  //modport for writeback stage
  modport writeback(
      input clk, Rst, dbg, mem_hold, f_stall,
      input MEM_WB_alures, MEM_WB_memres, MEM_WB_memread,
      input MEM_WB_regwrite, MEM_WB_rd, MEM_WB_fpusrc,
      input MEM_WB_mul_ready, MEM_WB_div_ready,
      input MEM_WB_mulres, MEM_WB_divres,
      input MEM_WB_CSR, MEM_WB_CSR_read,
      output WB_ID_regwrite, WB_ID_fpusrc, WB_ID_rd, WB_res, WB_ID_res
  );



endinterface

module riscv_core (
    riscv_bus_if rbus
);

  logic clk, Rst, debug, prog, mem_wea, dbg;
  logic [4:0] debug_input;
  logic [31:0] debug_output, mem_addr, mem_din, mem_dout;
  logic [3:0] mem_en;
  logic RAS_rdy;
  logic trap;



  always_comb begin
    clk = rbus.clk;
    Rst = rbus.Rst;
    debug = rbus.debug;
    prog = rbus.prog;
    debug_input = rbus.debug_input;
    mem_dout = rbus.mem_dout;
    RAS_rdy = rbus.RAS_rdy;
    bus.imem_dout = rbus.imem_dout;
    rbus.debug_output = (rbus.debug_input == 0) ? bus.IF_ID_pres_addr : debug_output;
    rbus.mem_wea = mem_wea;
    rbus.mem_rea = bus.mem_rea;
    rbus.mem_en = mem_en;
    rbus.mem_addr = mem_addr;
    rbus.mem_din = mem_din;
    rbus.imem_en = bus.imem_en;
    rbus.imem_addr = bus.imem_addr;
    rbus.imem_din = bus.uart_dout;
    rbus.imem_prog_ena = bus.memcon_prog_ena;
    rbus.branch = bus.branch;
    rbus.IF_ID_jal = bus.IF_ID_jal;
    rbus.IF_ID_rd = bus.IF_ID_rd;
    rbus.ins = bus.ins;
    rbus.IF_ID_pres_addr = bus.IF_ID_pres_addr;
    rbus.IF_ID_dout_rs1 = bus.IF_ID_dout_rs1;
    rbus.branoff = bus.branoff;
    rbus.next_addr = bus.next_addr;
  end


  main_bus_if bus (
      .mem_hold(rbus.mem_hold),
      .uart_IRQ(rbus.uart_IRQ),
      .*
  );

  assign rbus.storecntrl = bus.EX_MEM_storecntrl;
  assign rbus.trapping = bus.trapping;

  assign mem_wea = bus.mem_wea;
  assign mem_en = bus.mem_en;
  assign mem_addr = bus.mem_addr;
  assign mem_din = bus.mem_din;
  assign bus.mem_dout = mem_dout;
  assign bus.memcon_prog_ena = rbus.prog;


  assign bus.PC_En = (!bus.hz) & (rbus.RAS_rdy);
  assign dbg = (debug || prog);  //added to stop pipeline on prog and/or debug
  //debugging resister
  assign bus.adr_rs1 = debug ? debug_input : bus.IF_ID_rs1;


  always_ff @(posedge clk) begin
    if (Rst) begin
      debug_output <= 32'h00000000;
    end else if (prog) begin  //debug instruction memory
      debug_output <= bus.ins;
    end else if (debug) begin  //debug register
      debug_output <= bus.IF_ID_dout_rs1;
    end else begin
      debug_output <= 32'h00000000;
    end
  end

  fetch u1 (bus.fetch);

  //register file
  regfile u0 (bus.regfile);

  decode u2 (bus.decode);

  execute u3 (bus.execute);

  memory u4 (bus.memory);

  writeback u5 (bus.writeback);

  photon_core photon (bus);

  csr uC (.bus(bus));
endmodule
