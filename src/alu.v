//ALU operation Encoding
`define ALU_ADD  4'b0000  // add
`define ALU_SUB  4'b0001  // sub
`define ALU_SLL  4'b0010  // Shift Left Logical
`define ALU_SLT  4'b0011  // 有符号小于置1 (Set Less Than)
`define ALU_SLTU 4'b0100  // 无符号小于置1 (Set Less Than Unsigned)
`define ALU_XOR  4'b0101  // 按位异或
`define ALU_SRL  4'b0110  // 逻辑右移 (Shift Right Logical)
`define ALU_SRA  4'b0111  // 算术右移 (Shift Right Arithmetic)
`define ALU_OR   4'b1000  // 按位或
`define ALU_AND  4'b1001  // 按位与

`define ALU_BEQ  4'b1010  // ==
`define ALU_BNE  4'b1011  // !=
`define ALU_BLT  4'b1100  // < (有符号)
`define ALU_BGE  4'b1101  // >= (有符号)
`define ALU_BLTU 4'b1110  // < (无符号)
`define ALU_BGEU 4'b1111  // >= (无符号)

module alu(
    input [3:0] alu_op,
    input [31:0] op1,
    input [31:0] op2,
    output reg [31:0] result,
    output zero
);

    always @(*)begin
        case(alu_op)
            `ALU_ADD:  result = op1 + op2;
            `ALU_SUB:  result = op1 - op2;
            `ALU_SLL:  result = op1 << op2[4:0];
            `ALU_SLT:  result = ($signed(op1) < $signed(op2)) ? 32'd1 : 32'd0;
            `ALU_SLTU: result = (op1 < op2) ? 32'd1 : 32'd0;
            `ALU_XOR:  result = op1 ^ op2;
            `ALU_SRL:  result = op1 >> op2[4:0];
            `ALU_SRA:  result = $signed(op1) >>> op2[4:0];
            `ALU_OR:   result = op1 | op2;
            `ALU_AND:  result = op1 & op2;
            // 只要条件成立，强行让 result = 0，从而触发外部 zero 信号
            `ALU_BEQ:  result = (op1 == op2) ? 32'b0 : 32'b1;
            `ALU_BNE:  result = (op1 != op2) ? 32'b0 : 32'b1;
            `ALU_BLT:  result = ($signed(op1) < $signed(op2)) ? 32'b0 : 32'b1;
            `ALU_BGE:  result = ($signed(op1) >= $signed(op2)) ? 32'b0 : 32'b1;
            `ALU_BLTU: result = (op1 < op2) ? 32'b0 : 32'b1;
            `ALU_BGEU: result = (op1 >= op2) ? 32'b0 : 32'b1;
            default:   result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0) ? 1'b1 : 1'b0;
endmodule