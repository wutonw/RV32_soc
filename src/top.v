module top(
    input clk,
    input rst_n,

    output [31:0] inst_addr,
    input [31:0] inst,
);

    wire [31:0] pc;
    //decoder
    wire [4:0] rs1_addr;
    wire [4:0] rs2_addr;
    wire [4:0] rd_addr;
    wire reg_we;
    wire alu_src;
    wire [3:0] alu_op;
    wire mem_we;
    wire mem_to_reg;

    //RF
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    //Imm
    wire [31:0] imm;

    //alu
    wire [31:0] alu_result;
    wire alu_zero;
    wire [31:0] alu_operand_b;

    wire [31:0] reg_write_data;

    pc_reg u_pc_reg(
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc)
    );
    assign inst_addr = pc;

    //Decode
    decoder u_decoder (
        .inst       (inst),
        .rs1_addr   (rs1_addr),
        .rs2_addr   (rs2_addr),
        .rd_addr    (rd_addr),
        .reg_we     (reg_we),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .mem_we     (mem_we),
        .mem_to_reg (mem_to_reg)
    );
    imm_gen u_imm_gen (
        .inst (inst),
        .imm  (imm)
    );

    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rs1_addr),
        .rs1_data (rs1_data),
        .rs2_addr (rs2_addr),
        .rs2_data (rs2_data),
        .we       (reg_we),
        .rd_addr  (rd_addr),
        .rd_data  (reg_write_data) // 最终算出的数据写回
    );

    //EX
    assign alu_operand_b = (alu_src) ? imm : rs2_data;
    alu u_alu (
        .alu_op (alu_op),
        .op1    (rs1_data),
        .op2    (alu_operand_b),
        .result (alu_result),
        .zero   (alu_zero)
    );
    assign reg_write_data = alu_result;
endmodule