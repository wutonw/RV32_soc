module data_ram(
    input clk,
    input [3:0] we,//from mem_we(decoder)
    input [31:0] addr,
    input [31:0] wdata,
    output reg [31:0] rdata
);
    //1KB RAM
    reg [31:0] ram [0:255];
    //word address , addr / 4
    wire [7:0] word_index = addr[9:2];

    //write data to ram
    always @(posedge clk) begin
        if (we[0]) ram[word_index][7:0] <= wdata[7:0];
        if (we[1]) ram[word_index][15:8] <= wdata[15:8];
        if (we[2]) ram[word_index][23:16] <= wdata[23:16];
        if (we[3]) ram[word_index][31:24] <= wdata[31:24];
    end
    
    //read data from ram
    assign rdata = ram[word_index];
endmodule