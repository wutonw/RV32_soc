module axi_master_bridge(
    input clk,
    input rst_n,
    output reg axi_error,

    //cpu side
    input cpu_req,
    input cpu_we,//0:load, 1:store
    input [31:0] cpu_addr,
    input [31:0] cpu_wdata,
    input [3:0] cpu_wstrb,

    output reg [31:0] cpu_rdata,
    output cpu_stall,

    //AXI4_Lite side(5 channels)
    //AW
    output reg [31:0] aw_addr,
    output reg aw_valid,
    input aw_ready,

    //W
    output reg [31:0] w_data,
    output reg [3:0] w_strb,
    output reg w_valid,
    input w_ready,

    //B
    input [1:0] b_resp,
    input b_valid,
    output reg b_ready,

    //AR
    output reg [31:0] ar_addr,
    output reg ar_valid,
    input ar_ready,

    //R
    input [31:0] r_data,
    input [1:0] r_resp,
    input r_valid,
    output reg r_ready
);
    localparam IDLE = 5'b00001;
    localparam W_ADDR = 5'b00010;//写：发数据地址
    localparam W_RESP = 5'b00100;//写：等待回复
    localparam R_ADDR = 5'b01000;//读：送地址
    localparam R_DATA = 5'b10000;//读：等待回复

    reg [4:0] state;
    reg [4:0] next_state;

    //shakehand sucess
    wire aw_fire = aw_valid & aw_ready;
    wire w_fire = w_valid & w_ready;
    wire b_fire = b_valid & b_ready;
    wire ar_fire = ar_valid & ar_ready;
    wire r_fire = r_valid & r_ready;

    reg aw_done;
    reg w_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    always @(*)begin
        next_state = state;
        case(state)
            IDLE:begin
                if(cpu_req)begin
                    next_state = cpu_we ? W_ADDR : R_ADDR;
                end
            end
            W_ADDR:begin
                if((aw_done||aw_fire) && (w_done||w_fire))begin
                    next_state = W_RESP;
                end
            end
            W_RESP:begin
                if(b_fire)begin
                    next_state = IDLE;
                end
            end
            R_ADDR:begin
                if(ar_fire)begin
                    next_state = R_DATA;
                end
            end
            R_DATA:begin
                if(r_fire)begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            aw_valid <= 1'b0;
            w_valid <= 1'b0;
            b_ready <= 1'b0;
            ar_valid <= 1'b0;
            r_ready <= 1'b0;
            aw_done <= 1'b0;
            w_done <= 1'b0;
            axi_error <= 1'b0;
        end else begin
            b_ready <= 1'b0;
            r_ready <= 1'b0;
            case(state)
                IDLE:begin
                    aw_done <= 1'b0;
                    w_done <= 1'b0;
                    if(cpu_req)begin
                        if(cpu_we)begin
                            //write
                            aw_addr <= cpu_addr;
                            aw_valid <= 1'b1;
                            w_data <= cpu_wdata;
                            w_strb <= cpu_wstrb;
                            w_valid <= 1'b1;
                        end else begin
                            //read
                            ar_addr <= cpu_addr;
                            ar_valid <= 1'b1;
                        end
                    end
                end
                W_ADDR:begin
                    if(aw_fire)begin
                        aw_valid <= 1'b0;
                        aw_done <= 1'b1;
                    end
                    if(w_fire)begin
                        w_valid <= 1'b0;
                        w_done <= 1'b1;
                    end
                end
                W_RESP:begin
                    b_ready <= 1'b1;
                    if(b_fire)begin
                        if(b_resp != 2'b00) axi_error <= 1'b1;
                    end
                end
                R_ADDR: begin
                    if(ar_fire) begin
                        ar_valid <= 1'b0;
                    end
                end
                R_DATA:begin
                    r_ready <= 1'b1;
                    if(r_fire)begin
                        cpu_rdata <= r_data;
                        if(r_resp != 2'b00) axi_error <= 1'b1;
                    end
                end
            endcase
        end
    end
    assign cpu_stall = cpu_req &&(next_state != IDLE);
endmodule

