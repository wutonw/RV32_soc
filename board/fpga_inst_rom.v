module fpga_inst_rom (
    input  wire [31:0] addr,
    output wire [31:0] inst
);
    // Asynchronous read matches the current single-cycle CPU fetch path.
    // The build script pads this image to 256 words with RV32I NOPs.
    reg [31:0] rom_array [0:255];

    initial begin
        $readmemh("firmware.hex", rom_array);
    end

    assign inst = rom_array[addr[9:2]];
endmodule
