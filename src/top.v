module top(
    input clk,
    input rst_n,

    output [31:0] inst_addr,
    input [31:0] inst
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
    wire [1:0] wb_sel;
    wire branch;
    wire jump;
    wire jump_reg;

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

    //ram
    wire [31:0] mem_read_data;

    pc_reg u_pc_reg(
        .clk(clk),
        .rst_n(rst_n),
        .imm(imm),
        .alu_result(alu_result),
        .branch(branch),
        .jump(jump),
        .jump_reg(jump_reg),
        .zero(alu_zero),
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
        .wb_sel     (wb_sel),

        .branch     (branch),
        .jump       (jump), 
        .jump_reg   (jump_reg)
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

    data_ram u_data_ram (
        .clk   (clk),
        .we    (mem_we),
        .addr  (alu_result),
        .wdata (rs2_data),
        .rdata (mem_read_data)
    );

    wire [31:0] pc_plus_4 = pc + 32'd4;
    assign reg_write_data = (wb_sel == 2'b10) ? pc_plus_4 :
                            (wb_sel == 2'b01) ? mem_read_data :
                            alu_result;
endmodule