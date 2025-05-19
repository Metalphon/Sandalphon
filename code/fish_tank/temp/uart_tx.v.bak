module uart_tx
#(
	parameter CLK_FRE = 50,      //clock frequency(Mhz)
	parameter BAUD_RATE = 115200 //serial baud rate
)
(
	input                        clk,              //clock input
	input                        rst_n,            //asynchronous reset input, low active 
	input[7:0]                   tx_data,          //data to send
	input                        tx_data_valid,    //data to be sent is valid
	output reg                   tx_data_ready,    //send ready
	output                       tx_pin,           //serial data output
	input                        send_at_cmd       //trigger to send AT commands
);
//calculates the clock cycle for baud rate 
localparam                       CYCLE = CLK_FRE * 1000000 / BAUD_RATE;
//state machine code
localparam                       S_IDLE       = 1;
localparam                       S_START      = 2;//start bit
localparam                       S_SEND_BYTE  = 3;//data bits
localparam                       S_STOP       = 4;//stop bit
reg[2:0]                         state;
reg[2:0]                         next_state;
reg[15:0]                        cycle_cnt; //baud counter
reg[2:0]                         bit_cnt;//bit counter
reg[7:0]                         tx_data_latch; //latch data to send
reg                              tx_reg; //serial data output

// AT指令状态机
reg [3:0]                        at_state;
localparam                       AT_IDLE = 4'd0;
localparam                       AT_CIPMUX = 4'd1;
localparam                       AT_CIPSERVER = 4'd2;
localparam                       AT_CIPSEND = 4'd3;
localparam                       AT_DATA = 4'd4;

// AT指令字符串常量
reg [7:0] at_cipmux [0:11];    // AT+CIPMUX=1\r\n
reg [7:0] at_cipserver [0:19]; // AT+CIPSERVER=1,8081\r\n
reg [7:0] at_cipsend [0:17];   // AT+CIPSEND=0,1000\r\n
reg [7:0] at_char_cnt;         // AT指令字符计数器
reg at_cmd_done;               // AT指令发送完成标志
reg [7:0] at_tx_data;          // AT指令发送数据
reg at_tx_data_valid;          // AT指令发送数据有效
reg [24:0] delay_counter;      // 延时计数器
reg delay_done;                // 延时完成标志

// 初始化AT指令字符串
initial begin
    // AT+CIPMUX=1\r\n
    at_cipmux[0] = 8'h41; // A
    at_cipmux[1] = 8'h54; // T
    at_cipmux[2] = 8'h2B; // +
    at_cipmux[3] = 8'h43; // C
    at_cipmux[4] = 8'h49; // I
    at_cipmux[5] = 8'h50; // P
    at_cipmux[6] = 8'h4D; // M
    at_cipmux[7] = 8'h55; // U
    at_cipmux[8] = 8'h58; // X
    at_cipmux[9] = 8'h3D; // =
    at_cipmux[10] = 8'h31; // 1
    at_cipmux[11] = 8'h0D; // \r
    
    // AT+CIPSERVER=1,8081\r\n
    at_cipserver[0] = 8'h41; // A
    at_cipserver[1] = 8'h54; // T
    at_cipserver[2] = 8'h2B; // +
    at_cipserver[3] = 8'h43; // C
    at_cipserver[4] = 8'h49; // I
    at_cipserver[5] = 8'h50; // P
    at_cipserver[6] = 8'h53; // S
    at_cipserver[7] = 8'h45; // E
    at_cipserver[8] = 8'h52; // R
    at_cipserver[9] = 8'h56; // V
    at_cipserver[10] = 8'h45; // E
    at_cipserver[11] = 8'h52; // R
    at_cipserver[12] = 8'h3D; // =
    at_cipserver[13] = 8'h31; // 1
    at_cipserver[14] = 8'h2C; // ,
    at_cipserver[15] = 8'h38; // 8
    at_cipserver[16] = 8'h30; // 0
    at_cipserver[17] = 8'h38; // 8
    at_cipserver[18] = 8'h31; // 1
    at_cipserver[19] = 8'h0D; // \r
    
    // AT+CIPSEND=0,1000\r\n
    at_cipsend[0] = 8'h41; // A
    at_cipsend[1] = 8'h54; // T
    at_cipsend[2] = 8'h2B; // +
    at_cipsend[3] = 8'h43; // C
    at_cipsend[4] = 8'h49; // I
    at_cipsend[5] = 8'h50; // P
    at_cipsend[6] = 8'h53; // S
    at_cipsend[7] = 8'h45; // E
    at_cipsend[8] = 8'h4E; // N
    at_cipsend[9] = 8'h44; // D
    at_cipsend[10] = 8'h3D; // =
    at_cipsend[11] = 8'h30; // 0
    at_cipsend[12] = 8'h2C; // ,
    at_cipsend[13] = 8'h31; // 1
    at_cipsend[14] = 8'h30; // 0
    at_cipsend[15] = 8'h30; // 0
    at_cipsend[16] = 8'h30; // 0
    at_cipsend[17] = 8'h0D; // \r
end

assign tx_pin = tx_reg;

// AT指令状态机处理
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        at_state <= AT_IDLE;
        at_char_cnt <= 8'd0;
        at_cmd_done <= 1'b0;
        at_tx_data <= 8'd0;
        at_tx_data_valid <= 1'b0;
        delay_counter <= 25'd0;
        delay_done <= 1'b0;
    end
    else begin
        // 默认状态
        at_tx_data_valid <= 1'b0;
        
        // 延时计数器处理
        if (delay_counter > 0) begin
            delay_counter <= delay_counter - 1'b1;
            if (delay_counter == 1) begin
                delay_done <= 1'b1;
            end
        end
        else begin
            delay_done <= 1'b0;
        end
        
        // AT指令状态机
        case (at_state)
            AT_IDLE: begin
                // 空闲状态，等待触发发送AT指令
                at_char_cnt <= 8'd0;
                at_cmd_done <= 1'b0;
                if (send_at_cmd) begin
                    at_state <= AT_CIPMUX;
                end
            end
            
            AT_CIPMUX: begin
                // 发送AT+CIPMUX=1\r\n
                if (tx_data_ready && !at_tx_data_valid) begin
                    if (at_char_cnt <= 8'd11) begin
                        at_tx_data <= at_cipmux[at_char_cnt];
                        at_tx_data_valid <= 1'b1;
                        at_char_cnt <= at_char_cnt + 1'b1;
                    end
                    else if (at_char_cnt == 8'd12) begin
                        at_tx_data <= 8'h0A; // \n
                        at_tx_data_valid <= 1'b1;
                        at_char_cnt <= at_char_cnt + 1'b1;
                    end
                    else begin
                        at_char_cnt <= 8'd0;
                        delay_counter <= 25'd50_000_000; // 等待1秒
                        at_state <= AT_CIPSERVER;
                    end
                end
            end
            
            AT_CIPSERVER: begin
                // 等待延时完成后发送AT+CIPSERVER=1,8081\r\n
                if (delay_done) begin
                    if (tx_data_ready && !at_tx_data_valid) begin
                        if (at_char_cnt <= 8'd19) begin
                            at_tx_data <= at_cipserver[at_char_cnt];
                            at_tx_data_valid <= 1'b1;
                            at_char_cnt <= at_char_cnt + 1'b1;
                        end
                        else if (at_char_cnt == 8'd20) begin
                            at_tx_data <= 8'h0A; // \n
                            at_tx_data_valid <= 1'b1;
                            at_char_cnt <= at_char_cnt + 1'b1;
                        end
                        else begin
                            at_char_cnt <= 8'd0;
                            delay_counter <= 25'd50_000_000; // 等待1秒
                            at_state <= AT_CIPSEND;
                        end
                    end
                end
            end
            
            AT_CIPSEND: begin
                // 等待延时完成后发送AT+CIPSEND=0,1000\r\n
                if (delay_done) begin
                    if (tx_data_ready && !at_tx_data_valid) begin
                        if (at_char_cnt <= 8'd17) begin
                            at_tx_data <= at_cipsend[at_char_cnt];
                            at_tx_data_valid <= 1'b1;
                            at_char_cnt <= at_char_cnt + 1'b1;
                        end
                        else if (at_char_cnt == 8'd18) begin
                            at_tx_data <= 8'h0A; // \n
                            at_tx_data_valid <= 1'b1;
                            at_char_cnt <= at_char_cnt + 1'b1;
                        end
                        else begin
                            at_char_cnt <= 8'd0;
                            delay_counter <= 25'd50_000_000; // 等待1秒
                            at_state <= AT_DATA;
                        end
                    end
                end
            end
            
            AT_DATA: begin
                // 数据发送阶段，等待外部数据输入
                // 在实际应用中，这里可以添加发送实际数据的逻辑
                // 数据发送完成后，可以返回到AT_CIPSEND状态，准备下一轮发送
                if (delay_done) begin
                    at_state <= AT_CIPSEND; // 循环发送AT+CIPSEND指令
                end
            end
            
            default: begin
                at_state <= AT_IDLE;
            end
        endcase
    end
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		state <= S_IDLE;
	else
		state <= next_state;
end

always@(*)
begin
	case(state)
		S_IDLE:
			if((tx_data_valid == 1'b1) || (at_tx_data_valid == 1'b1))
				next_state <= S_START;
			else
				next_state <= S_IDLE;
		S_START:
			if(cycle_cnt == CYCLE - 1)
				next_state <= S_SEND_BYTE;
			else
				next_state <= S_START;
		S_SEND_BYTE:
			if(cycle_cnt == CYCLE - 1  && bit_cnt == 3'd7)
				next_state <= S_STOP;
			else
				next_state <= S_SEND_BYTE;
		S_STOP:
			if(cycle_cnt == CYCLE - 1)
				next_state <= S_IDLE;
			else
				next_state <= S_STOP;
		default:
			next_state <= S_IDLE;
	endcase
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		begin
			tx_data_ready <= 1'b0;
		end
	else if(state == S_IDLE)
		if((tx_data_valid == 1'b1) || (at_tx_data_valid == 1'b1))
			tx_data_ready <= 1'b0;
		else
			tx_data_ready <= 1'b1;
	else if(state == S_STOP && cycle_cnt == CYCLE - 1)
			tx_data_ready <= 1'b1;
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		begin
			tx_data_latch <= 8'd0;
		end
	else if(state == S_IDLE)
		if(tx_data_valid == 1'b1)
			tx_data_latch <= tx_data;
		else if(at_tx_data_valid == 1'b1)
			tx_data_latch <= at_tx_data;
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		begin
			bit_cnt <= 3'd0;
		end
	else if(state == S_SEND_BYTE)
		if(cycle_cnt == CYCLE - 1)
			bit_cnt <= bit_cnt + 3'd1;
		else
			bit_cnt <= bit_cnt;
	else
		bit_cnt <= 3'd0;
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		cycle_cnt <= 16'd0;
	else if((state == S_SEND_BYTE && cycle_cnt == CYCLE - 1) || next_state != state)
		cycle_cnt <= 16'd0;
	else
		cycle_cnt <= cycle_cnt + 16'd1;	
end

always@(posedge clk or negedge rst_n)
begin
	if(rst_n == 1'b0)
		tx_reg <= 1'b1;
	else
		case(state)
			S_IDLE,S_STOP:
				tx_reg <= 1'b1; 
			S_START:
				tx_reg <= 1'b0; 
			S_SEND_BYTE:
				tx_reg <= tx_data_latch[bit_cnt];
			default:
				tx_reg <= 1'b1; 
		endcase
end

endmodule