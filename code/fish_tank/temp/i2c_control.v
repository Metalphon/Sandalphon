/*============================================================================
*
*  LOGIC CORE:          I2C控制器顶层模块	
*  MODULE NAME:         i2c_control()
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

module i2c_control(
	input Clk,
	input Rst_n,
	
	input wrreg_req,
	input rdreg_req,
	input lrdreg_req,
	input [15:0]addr,
	input addr_mode,
	input [7:0]wrdata,
	output reg[7:0]rddata,
	input [7:0]device_id,
	output reg RW_Done,
	output reg LRW_Done,
	output reg [47:0] l_rddata , 
	output [3:0] led  , 
	
	
	
	output reg ack,

	output i2c_sclk,
	inout i2c_sdat
);


	
	reg [5:0]Cmd;
	reg [7:0]Tx_DATA;
	wire Trans_Done;
	wire ack_o;
	reg Go;
	wire [15:0] reg_addr;
	
	assign reg_addr = addr_mode?addr:{addr[7:0],addr[15:8]};
	
	
	wire [7:0]Rx_DATA;
	
	localparam 
		WR   =  6'b000001,	// 写请求
		STA  =  6'b000010,	//起始位请求
		RD   =  6'b000100,	//读请求
		STO  =  6'b001000,	//停止位请求
		ACK  =  6'b010000,	//应答位请求
		NACK =  6'b100000;	//无应答请求
	
	i2c_bit_shift i2c_bit_shift(
		.Clk(Clk),
		.Rst_n(Rst_n),
		.Cmd(Cmd),
		.Go(Go),
		.Rx_DATA(Rx_DATA),
		.Tx_DATA(Tx_DATA),
		.Trans_Done(Trans_Done),
		.ack_o(ack_o),
		.i2c_sclk(i2c_sclk),
		.i2c_sdat(i2c_sdat)
	);
	
	reg [3:0]state;
	reg [3:0]cnt;

	// assign led = state;
	
	localparam
		IDLE             = 4'd01,
		WR_REG           = 4'd02,
		WAIT_WR_DONE     = 4'd03,
		WR_REG_DONE      = 4'd04,
		RD_REG           = 4'd05,
		WAIT_RD_DONE     = 4'd06,
		RD_REG_DONE      = 4'd07,
		LRD_REG          = 4'd08,
		WAIT_LRD_DONE    = 4'd09,
		LRD_REG_DONE     = 4'd10;
	
	always@(posedge Clk or negedge Rst_n)
	if(!Rst_n)begin
		Cmd <= 6'd0;
		Tx_DATA <= 8'd0;
		Go <= 1'b0;
		rddata <= 0;
		l_rddata <= 0;
		state <= IDLE;
		ack <= 0;
	end
	else begin
		case(state)
			IDLE:
				begin
					cnt <= 0;
					ack <= 0;
					RW_Done <= 1'b0;					
					LRW_Done <= 1'b0;					
					if(wrreg_req)
						state <= WR_REG;
					else if(rdreg_req)
						state <= RD_REG;
					else if(lrdreg_req)
					    state <= LRD_REG;
					else
						state <= IDLE;
				end
			
			WR_REG:
				begin
					state <= WAIT_WR_DONE;
					case(cnt)
						0:write_byte(WR | STA, device_id);
						1:write_byte(WR, reg_addr[15:8]);
						2:write_byte(WR, reg_addr[7:0]);
						3:write_byte(WR | STO, wrdata);
						default:;
					endcase
				end
						
			WAIT_WR_DONE:
				begin
					Go <= 1'b0; 
					if(Trans_Done)begin
						ack <= ack | ack_o;
						case(cnt)
							0: begin cnt <= 1; state <= WR_REG;end
							1: 
								begin 
									state <= WR_REG;
									if(addr_mode)
										cnt <= 2; 
									else
										cnt <= 3;
								end
									
							2: begin
									cnt <= 3;
									state <= WR_REG;
								end
							3:state <= WR_REG_DONE;
							default:state <= IDLE;
						endcase
					end
				end
								
			WR_REG_DONE:
				begin
					RW_Done <= 1'b1;
					state <= IDLE;
				end
				
			RD_REG:
				begin
					state <= WAIT_RD_DONE;
					case(cnt)
						0:write_byte(WR | STA, device_id);
						1:if(addr_mode)
								write_byte(WR, reg_addr[15:8]);
							else
								write_byte(WR , reg_addr[15:8]);
						2:write_byte(WR , reg_addr[7:0]);
						3:write_byte(WR | STA, device_id | 8'd1);
						4:read_byte(RD | NACK | STO);
						default:;
					endcase
				end
				
			WAIT_RD_DONE:
				begin
					Go <= 1'b0; 
					if(Trans_Done)begin
						if(cnt <= 3)
							ack <= ack | ack_o;
						case(cnt)
							0: begin cnt <= 1; state <= RD_REG;end
							1: 
								begin 
									state <= RD_REG;
									if(addr_mode)
										cnt <= 2; 
									else
										cnt <= 3;
								end
									
							2: begin
									cnt <= 3;
									state <= RD_REG;
								end
							3:begin
									cnt <= 4;
									state <= RD_REG;
								end
							4:state <= RD_REG_DONE;
							default:state <= IDLE;
						endcase
					end
				end
				
			RD_REG_DONE:
				begin
					RW_Done <= 1'b1;
					rddata <= Rx_DATA;
					state <= IDLE;				
				end

			LRD_REG:
				begin
					state <= WAIT_LRD_DONE;
					case(cnt)
						0:write_byte(WR | STA, device_id);
						1:if(addr_mode)
								write_byte(WR, reg_addr[15:8]);
							else
								write_byte(WR, reg_addr[15:8]);
						2:write_byte(WR, reg_addr[7:0]);
						3:write_byte(WR | STA, device_id | 8'd1);
						4,5,6,7,8:read_byte(RD | ACK);
						9:read_byte(RD | NACK | STO);
						default:;
					endcase
				end
				
			WAIT_LRD_DONE:
				begin
					Go <= 1'b0; 
					if(Trans_Done)begin
						if(cnt <= 3)
							ack <= ack | ack_o;
						case(cnt)
							0: begin cnt <= 1; state <= LRD_REG;end
							1: 
								begin 
									state <= LRD_REG;
									if(addr_mode)
										cnt <= 2; 
									else
										cnt <= 3;
								end
							2: begin
									cnt <= 3;
									state <= LRD_REG;
								end
							3:begin
									cnt <= 4;
									state <= LRD_REG;
								end
							4: begin					//data
									cnt <= 5;
									state <= LRD_REG;
									l_rddata[47:40] <= {6'd0,Rx_DATA[1:0]};
								end
							5:begin
									cnt <= 6;
									state <= LRD_REG;
									l_rddata[39:32] <= Rx_DATA;
								end
							6: begin
									cnt <= 7;
									state <= LRD_REG;
									l_rddata[31:24] <= Rx_DATA;
								end
							7:begin
									cnt <= 8;
									state <= LRD_REG;
									l_rddata[23:16] <= {6'd0,Rx_DATA[1:0]};
								end
							8: begin
									cnt <= 9;
									state <= LRD_REG;
									l_rddata[15:8] <= Rx_DATA;
								end
							9:state <= LRD_REG_DONE;
							default:state <= IDLE;
						endcase
					end
				end
				
			LRD_REG_DONE:
				begin
					LRW_Done <= 1'b1;
					l_rddata[7:0] <= Rx_DATA;
					state <= IDLE;				
				end
			default:state <= IDLE;
		endcase
	end
	
	task read_byte;
		input [5:0]Ctrl_Cmd;
		begin
			Cmd <= Ctrl_Cmd;
			Go <= 1'b1; 
		end
	endtask
	
	task write_byte;
		input [5:0]Ctrl_Cmd;
		input [7:0]Wr_Byte_Data;
		begin
			Cmd <= Ctrl_Cmd;
			Tx_DATA <= Wr_Byte_Data;
			Go <= 1'b1; 
		end
	endtask

endmodule
