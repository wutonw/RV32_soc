module regfile(
    input clk,
    input rst_n,

    //read port 1
    input [4:0] rs1_addr,
    output [31:0] rs1_data,

    //read port 2
    input [4:0] rs2_addr,
    output [31:0] rs2_data,

    //write port
    input we,//rd_en
    input [4:0] rd_addr,
    input [31:0] rd_data
);

    reg [31:0] regs [0:31];//32 registers of 32 bits

    //write logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<32;i = i+ 1)begin
                reg[i] <= 32'b0;
            end 
        end else if (we && rd_addr != 0) begin
                regs[rd_addr] <= rd_data;
        end
    end

    //read logic
    assign rs1_data = (rs1_addr == 0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : regs[rs2_addr];
    
endmodule