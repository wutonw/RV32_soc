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
            default:   result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0) ? 1'b1 : 1'b0;
endmodule