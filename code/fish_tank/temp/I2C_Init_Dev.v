/*============================================================================
*
*  LOGIC CORE:          使用IIC初始化一个设备的寄存器顶层文件	
*  MODULE NAME:         I2C_Init_Dev()
*  COMPANY:             武汉芯路恒科技有限公司
*                       http://xiaomeige.taobao.com
*	author:					小梅哥
*	Website:					www.corecourse.cn
*  REVISION HISTORY:  
*
*    Revision 1.0  04/10/2019     Description: Initial Release.
*
*  FUNCTIONAL DESCRIPTION:
===========================================================================*/

module I2C_Init_Dev(
	input Clk,
	input Rst_n,
	input Go,
	input key_cnt,

	input intr,
    output reg [35:0] l_rddata,
	output reg LRW_Done,
    output [3:0] led,
	output     reg [3:0] state_cnt,
	
	output i2c_sclk,
	inout i2c_sdat
);


	wire [47:0] l_rddata_w;
	wire LRW_Done_w;
	wire [7:0]addr;
	reg [7:0] addr0;
	reg [7:0] addr1;
	reg wrreg_req;
	reg rdreg_req;
	reg [7:0]wrdata;
	
	wire [7:0]rddata;
	wire RW_Done;
	wire ack;
	//
	reg Init_Done;
	reg lrdreg_req;

    reg fifo_full ;
    reg read_ready;
    wire [47:0]rddata_l;

	//


	
	wire [7:0]lut_size;	//初始化表中需要传输的数据总数
	
	reg [7:0]cnt;	//传输次数计数器

	always@(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)begin
			l_rddata <= 36'd0 ;
		end
		else begin
			l_rddata <= {l_rddata_w[41:24],l_rddata_w[17:0]} ;
		end
	end

	always@(posedge Clk or negedge Rst_n)begin
		if(!Rst_n)begin
			LRW_Done <= 1'd0 ;
		end
		else begin
			LRW_Done <= LRW_Done_w ;
		end
	end
	
	
	
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)
		cnt <= 0;
	else if(Go) 
		cnt <= 0;
	else if(cnt < lut_size)begin
		if(RW_Done && (!ack))
			cnt <= cnt + 1'b1;
		else
			cnt <= cnt;
	end
	else
		cnt <= 0;
		
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)
		Init_Done <= 0;
	else if(Go) 
		Init_Done <= 0;
	else if(cnt == lut_size)
		Init_Done <= 1;

	reg [1:0]state;
		
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)begin
		state <= 0;
		wrreg_req <= 1'b0;
	end
	else if(cnt < lut_size)begin
		case(state)
			0:
				if(Go)
					state <= 1;
				else
					state <= 0;
			
			1:
				begin
					wrreg_req <= 1'b1;
					addr0 <= lut[15:8] ;
					wrdata <= lut[7:0];
					state <= 2;
				end
				
			2:
				begin
					wrreg_req <= 1'b0;
					if(RW_Done)
						state <= 1;
					else
						state <= 2;
				end
				
			default:state <= 0;
		endcase
	end
	else
		state <= 0;

	// assign led = {intr,state_cnt};

    always@(posedge Clk or negedge Rst_n)begin
        if(!Rst_n)begin
            state_cnt <= 4'd0 ;
            rdreg_req <= 1'b0;
            lrdreg_req <= 1'b0;
            fifo_full   <= 1'b0;
            read_ready  <= 1'b0;
        end
        else begin
            case (state_cnt)
                4'd0:begin
                    rdreg_req <= 1'b0;
                    lrdreg_req <= 1'b0;
                    state_cnt <= 4'd1;
                end 
                4'd1:begin
                    if(Init_Done && (!intr)) begin
                        rdreg_req <= 1'b1;
                        addr1 <= 8'h00;
                        state_cnt <= 4'd2;
                    end
                end
                4'd2:begin
                    rdreg_req <= 1'b1;
                    if(RW_Done)
                    begin
                        state_cnt <= 4'd3;
                        fifo_full <= rddata[7];
                        read_ready <= rddata[6];
                    end
                end
                4'd3:begin
                    rdreg_req <= 1'b0;
                    if(~ack) begin
                        state_cnt <= 4'd4;
                    end
                end
                4'd4:begin
                    // if(read_ready || fifo_full) begin
                        lrdreg_req <= 1'b1;
                        addr1 <= 8'h07;
                        state_cnt <= 4'd5;
                    // end
                end
                4'd5:begin
                    lrdreg_req <= 1'b1;
                    if(LRW_Done_w)
                    begin
                        state_cnt <= 4'd6;
                    end
                end
                4'd6:begin
                    state_cnt <= 4'd0;
                end
                default: state_cnt <= 4'd0;
            endcase
        end
    end

	wire [15:0]lut;
	wire [7:0]dev_id;
	max30102_init_table u_max30102_init_table(
		.dev_id(dev_id),
		.lut_size(lut_size),

		.key_cnt(key_cnt),
		.addr(cnt),
		.clk(Clk),
		.q(lut)
	);
	
	assign addr = (Init_Done) ? addr1 : addr0;

	i2c_control i2c_control(
		.Clk(Clk),
		.Rst_n(Rst_n),
		.wrreg_req(wrreg_req),
		.rdreg_req(rdreg_req),
        .lrdreg_req(lrdreg_req),
		.addr(addr),
		.addr_mode(0),
		.wrdata( wrdata ),
		.rddata(rddata),
		.device_id(8'hAE),
		.RW_Done( RW_Done ),
        .LRW_Done(LRW_Done_w),
        .l_rddata(l_rddata_w),
		.ack(ack),	
		.led(led),	
		.i2c_sclk(i2c_sclk),
		.i2c_sdat(i2c_sdat)
	);

endmodule
