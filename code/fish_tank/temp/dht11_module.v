module dht11_module(
    input               sys_clk     ,       
    input               rst_n       ,       
    inout               dht11       ,       
    output  reg [7:0]   temp_value  ,       
    output  reg [7:0]   humi_value  ,       
    output  reg [3:0]   state,
    output  reg         data_valid               
);

localparam  WAIT_1S     = 6'b000001 , 
            START       = 6'b000010 , 
            DELAY_10us  = 6'b000100 , 
            REPLY       = 6'b001000 , 
            DELAY_75us  = 6'b010000 , 
            REV_data    = 6'b100000 ; 

localparam  T_1S = 999_999  ,               
            T_BE = 17_999    ,               
            T_GO = 12        ;               

reg [6:0]   cur_state   ;                   
reg [6:0]   next_state  ;                   
reg [4:0]   cnt         ;                   
reg         dht11_out   ;                   
reg         dht11_en    ;                   
reg         dht11_d1    ;                   
reg         dht11_d2    ;                   
reg         clk_us      ;                   
reg [21:0]  cnt_us      ;                   
reg [5:0]   bit_cnt     ;                   
reg [39:0]  data_temp   ;                   

wire        dht11_in    ;                   
wire        dht11_rise  ;                   
wire        dht11_fall  ;                   

assign  dht11_in = dht11;                           
assign  dht11 =  dht11_en ? dht11_out : 1'bz;      

always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        cnt <= 5'd0;
    else if(cnt == 5'd24)               
        cnt <= 5'd0;
    else
        cnt <= cnt + 1'd1;
end

always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        clk_us <= 1'b0;
    else  if(cnt == 5'd24)              
        clk_us <= ~clk_us;              
    else
        clk_us <= clk_us;
end

assign  dht11_rise = ~dht11_d2 && dht11_d1;         
assign  dht11_fall = ~dht11_d1 && dht11_d2;         

always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)begin
        dht11_d1 <= 1'b0;               
        dht11_d2 <= 1'b0;               
    end
    else begin
        dht11_d1 <= dht11;              
        dht11_d2 <= dht11_d1;           
    end
end

always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)      
        cur_state <= WAIT_1S;           
    else
        cur_state <= next_state;
end

always @(*)begin
    next_state = WAIT_1S;
    case(cur_state)
        WAIT_1S     :begin
            if(cnt_us == T_1S)              
                next_state = START;          
            else    
                next_state = WAIT_1S;       
        end 
        START       :begin   
            if(cnt_us == T_BE)              
                next_state = DELAY_10us;    
            else
                next_state = START;         
        end
        DELAY_10us  :begin                  
            if(cnt_us == T_GO)              
                next_state = REPLY;         
            else
                next_state = DELAY_10us;    
        end
        REPLY       :begin
            if(cnt_us <= 'd500)begin        
                if(dht11_rise && cnt_us >= 'd70 
                  && cnt_us <= 'd100)               
                    next_state = DELAY_75us;        
                else
                    next_state = REPLY;             
            end 
            else    
                next_state = START;                 
        end 
        DELAY_75us  :begin   
            if(dht11_fall && cnt_us >= 'd70)       
                next_state = REV_data;              
            else    
                next_state = DELAY_75us;           
        end 
        REV_data    :begin   
            if(dht11_rise && bit_cnt == 'd40)      
                next_state = START;                 
            else    
                next_state = REV_data;             
        end 
        default:next_state = START;                
    endcase
end 

always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)begin                                    
        dht11_en <= 1'b0;
        dht11_out <= 1'b0;
        cnt_us <= 22'd0;
        bit_cnt <=  6'd0;
        data_temp <= 40'd0;     
    end
    else    
        case(cur_state)
            WAIT_1S     :begin
                dht11_en <= 1'b0;                      
                if(cnt_us == T_1S)                     
                    cnt_us <= 22'd0;                   
                else
                    cnt_us <= cnt_us + 1'd1;           
            end
            START       :begin
                dht11_en <= 1'b1;                      
                dht11_out <= 1'b0;                     
                if(cnt_us == T_BE)      
                    cnt_us <= 22'd0;                   
                else        
                    cnt_us <= cnt_us + 1'd1;           
            end     
            DELAY_10us  :begin      
                dht11_en <= 1'b0;                      
                if(cnt_us == T_GO)
                    cnt_us <= 22'd0;                   
                else                                    
                    cnt_us <= cnt_us + 1'd1;           
            end 
            REPLY       :begin
                dht11_en <= 1'b0;                      
                if(cnt_us <= 'd500)begin               
                    if(dht11_rise && cnt_us >= 'd70 
                      && cnt_us <= 'd100)              
                        cnt_us <= 22'd0;               
                    else
                        cnt_us <= cnt_us + 1'd1;       
                end
                else 
                    cnt_us <= 22'd0;                   
            end 
            DELAY_75us  :begin
                dht11_en <= 1'b0;                      
                if(dht11_fall && cnt_us >= 'd70)       
                    cnt_us <= 22'd0;                   
                else    
                    cnt_us <= cnt_us + 1'd1;           
            end
            REV_data    :begin
                dht11_en <= 1'b0;                      
                if(dht11_rise && bit_cnt == 'd40)begin 
                    bit_cnt <=  6'd0;                  
                    cnt_us <= 22'd0;                   
                end
                else if(dht11_fall)begin               
                    bit_cnt <= bit_cnt + 1'd1;         
                    cnt_us <= 22'd0;                   
                    if(cnt_us <= 'd100)                
                        data_temp[39-bit_cnt] <= 1'b0; 
                    else 
                        data_temp[39-bit_cnt] <= 1'b1; 
                end
                else begin                             
                    bit_cnt <= bit_cnt;              
                    data_temp <= data_temp;
                    cnt_us <= cnt_us + 1'd1;           
                end
            end
            default:;       
        endcase
end

always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n) begin
        temp_value <= 8'd0;
        humi_value <= 8'd0;
        data_valid <= 1'b0;
    end
    else if((data_temp[7:0] == data_temp[39:32] + data_temp[31:24] +
    data_temp[23:16] + data_temp[15:8])) begin
        temp_value <= data_temp[23:16];    
        humi_value <= data_temp[39:32];    
        data_valid <= 1'b1;
    end
    else
        data_valid <= 1'b0;
end

always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)
        state <= 4'd0;
    else
        case(cur_state)
            WAIT_1S:    state <= 4'd0;
            START:      state <= 4'd1;
            DELAY_10us: state <= 4'd2;
            REPLY:      state <= 4'd3;
            DELAY_75us: state <= 4'd4;
            REV_data:   state <= 4'd5;
            default:    state <= 4'd0;
        endcase
end

endmodule 