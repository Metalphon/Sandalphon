//==================================================================
//--3娈靛紡鐘舵€佹満锛圡oore锛夊疄鐜扮殑DHT11椹卞姩
//==================================================================

module dht11_module(
    input               sys_clk     ,       //绯荤粺鏃堕挓锛0M
    input               rst_n       ,       //浣庣數骞虫湁鏁堢殑澶嶄綅淇″彿    
    inout               dht11       ,       //鍗曟€荤嚎锛堝弻鍚戜俊鍙凤級
    output  reg [7:0]   temp_value  ,       //娓╁害鍊艰緭鍑
    output  reg [7:0]   humi_value  ,       //婀垮害鍊艰緭鍑
    output  reg [3:0]   state               //鐘舵€佽緭鍑
);

//------------<鍙傛暟瀹氫箟>----------------------------------------------
//鐘舵€佹満鐘舵€佸畾涔夛紝浣跨敤鐙儹鐮侊紙onehot code锛
localparam  WAIT_1S     = 6'b000001 ,
            START       = 6'b000010 ,
            DELAY_10us  = 6'b000100 ,
            REPLY       = 6'b001000 ,
            DELAY_75us  = 6'b010000 ,
            REV_data    = 6'b100000 ;
//鏃堕棿鍙傛暟瀹氫箟
localparam  T_1S = 999_999  ,               //涓婄數1s寤舵椂璁℃暟锛屽崟浣島s
            T_BE = 17_999    ,               //涓绘満璧峰淇″彿鎷変綆鏃堕棿锛屽崟浣島s
            T_GO = 12        ;               //涓绘満閲婃斁鎬荤嚎鏃堕棿锛屽崟浣島s

//------------<reg瀹氫箟>----------------------------------------------                                    
reg [6:0]   cur_state   ;                   //鐜版€
reg [6:0]   next_state  ;                   //娆℃€
reg [4:0]   cnt         ;                   //50鍒嗛璁℃暟鍣紝1Mhz(1us)
reg         dht11_out   ;                   //鍙屽悜鎬荤嚎杈撳嚭
reg         dht11_en    ;                   //鍙屽悜鎬荤嚎杈撳嚭浣胯兘锛鍒欒緭鍑猴紝0鍒欓珮闃绘€
reg         dht11_d1    ;                   //鎬荤嚎淇″彿鎵鎷
reg         dht11_d2    ;                   //鎬荤嚎淇″彿鎵鎷
reg         clk_us      ;                   //us鏃堕挓
reg [21:0]  cnt_us      ;                   //us璁℃暟鍣鏈€澶у彲琛ㄧず4.2s
reg [5:0]   bit_cnt     ;                   //鎺ユ敹鏁版嵁璁℃暟鍣紝鏈€澶у彲浠ヨ〃绀4浣
reg [39:0]  data_temp   ;                   //鍖呭惈鏍￠獙鐨0浣嶈緭鍑

//------------<wire瀹氫箟>----------------------------------------------        
wire        dht11_in    ;                   //鍙屽悜鎬荤嚎杈撳叆
wire        dht11_rise  ;                   //涓婂崌娌
wire        dht11_fall  ;                   //涓嬮檷娌

//==================================================================
//===========================<main  code>===========================
//==================================================================

//-----------------------------------------------------------------------
//--鍙屽悜绔彛浣跨敤鏂瑰紡
//-----------------------------------------------------------------------
assign  dht11_in = dht11;                           //楂橀樆鎬佺殑璇濓紝鍒欐妸鎬荤嚎涓婄殑鏁版嵁璧嬬粰dht11_in
assign  dht11 =  dht11_en ? dht11_out : 1'bz;      //浣胯兘1鍒欒緭鍑猴紝0鍒欓珮闃绘€

//-----------------------------------------------------------------------
//--us鏃堕挓鐢熸垚锛屽洜涓烘椂搴忛兘鏄互us涓哄崟浣嶏紝鎵€浠ョ敓鎴愪竴涓us鐨勬椂閽熶細姣旇緝鏂逛究
//-----------------------------------------------------------------------
//50鍒嗛璁℃暟
always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        cnt <= 5'd0;
    else if(cnt == 5'd24)               //姣5涓椂閽00ns娓呴浂
        cnt <= 5'd0;
    else
        cnt <= cnt + 1'd1;
end

//鐢熸垚1us鏃堕挓
always @(posedge sys_clk or negedge rst_n)begin
    if(!rst_n)
        clk_us <= 1'b0;
    else  if(cnt == 5'd24)              //姣00ns
        clk_us <= ~clk_us;              //鏃堕挓鍙嶈浆
    else
        clk_us <= clk_us;
end

//-----------------------------------------------------------------------
//--涓婂崌娌夸笌涓嬮檷娌挎娴嬬數璺
//-----------------------------------------------------------------------
//妫€娴嬫€荤嚎涓婄殑涓婂崌娌垮拰涓嬮檷娌
assign  dht11_rise = ~dht11_d2 && dht11_d1;         //涓婂崌娌
assign  dht11_fall = ~dht11_d1 && dht11_d2;         //涓嬮檷娌

//dht11鎵撴媿锛屾崟鑾蜂笂鍗囨部鍜屼笅闄嶆部
always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)begin
        dht11_d1 <= 1'b0;               //澶嶄綅鍒濆涓
        dht11_d2 <= 1'b0;               //澶嶄綅鍒濆涓
    end
    else begin
        dht11_d1 <= dht11;              //鎵鎷
        dht11_d2 <= dht11_d1;           //鎵鎷
    end
end

//-----------------------------------------------------------------------
//--涓夋寮忕姸鎬佹満
//-----------------------------------------------------------------------
//鐘舵€佹満绗竴娈碉細鍚屾鏃跺簭鎻忚堪鐘舵€佽浆绉
always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)      
        cur_state <= WAIT_1S;           
    else
        cur_state <= next_state;
end

//鐘舵€佹満绗簩娈碉細缁勫悎閫昏緫鍒ゆ柇鐘舵€佽浆绉绘潯浠讹紝鎻忚堪鐘舵€佽浆绉昏寰嬩互鍙婅緭鍑
always @(*)begin
    next_state = WAIT_1S;
    case(cur_state)
        WAIT_1S     :begin
            if(cnt_us == T_1S)              //婊¤冻涓婄數寤舵椂鐨勬椂闂   
                next_state = START;          //璺宠浆鍒癝TART
            else    
                next_state = WAIT_1S;       //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
        end 
        START       :begin   
            if(cnt_us == T_BE)              //婊¤冻鎷変綆鎬荤嚎鐨勬椂闂
                next_state = DELAY_10us;    //璺宠浆鍒癉ELAY_10us
            else
                next_state = START;         //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
        end
        DELAY_10us  :begin                  
            if(cnt_us == T_GO)              //婊¤冻涓绘満閲婃斁鎬荤嚎鏃堕棿
                next_state = REPLY;         //璺宠浆鍒癛EPLY
            else
                next_state = DELAY_10us;    //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
        end
        REPLY       :begin
            if(cnt_us <= 'd500)begin        //涓嶅埌500us
                if(dht11_rise && cnt_us >= 'd70 
                  && cnt_us <= 'd100)               //涓婂崌娌垮搷搴旓紝涓斾綆鐢靛钩鏃堕棿浠嬩簬70~100us
                    next_state = DELAY_75us;        //璺宠浆鍒癉ELAY_75us
                else
                    next_state = REPLY;             //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
            end 
            else    
                next_state = START;                 //瓒呰繃500us浠嶆病鏈変笂鍗囨部鍝嶅簲鍒欒烦杞埌START
        end 
        DELAY_75us  :begin   
            if(dht11_fall && cnt_us >= 'd70)       //涓婂崌娌垮搷搴旓紝涓斾綆鐢靛钩鏃堕棿澶т簬70us
                next_state = REV_data;              //璺宠浆鍒癛EV_data
            else    
                next_state = DELAY_75us;           //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
        end 
        REV_data    :begin   
            if(dht11_rise && bit_cnt == 'd40)      //鎺ユ敹瀹屼簡鎵€鏈0涓暟鎹悗浼氭媺浣庝竴娈垫椂闂翠綔涓虹粨鏉
                                                   //鎹曟崏鍒颁笂鍗囨部涓旀帴鏀舵暟鎹釜鏁颁负40                
                next_state = START;                 //鐘舵€佽烦杞埌START锛岄噸鏂板紑濮嬫柊涓€杞噰闆
            else    
                next_state = REV_data;             //鏉′欢涓嶆弧瓒崇姸鎬佷笉鍙
        end 
        default:next_state = START;                //榛樿鐘舵€佷负START
    endcase
end 

//鐘舵€佹満绗笁娈碉細鏃跺簭閫昏緫鎻忚堪杈撳嚭
always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n)begin                                    //澶嶄綅鐘舵€佷笅杈撳嚭濡備笅                        
        dht11_en <= 1'b0;
        dht11_out <= 1'b0;
        cnt_us <= 22'd0;
        bit_cnt <=  6'd0;
        data_temp <= 40'd0;     
    end
    else    
        case(cur_state)
            WAIT_1S     :begin
                dht11_en <= 1'b0;                      //閲婃斁鎬荤嚎锛岀敱澶栭儴鐢甸樆鎷夐珮
                if(cnt_us == T_1S)                     
                    cnt_us <= 22'd0;                   //璁℃椂婊¤冻鏉′欢鍒欐竻闆
                else
                    cnt_us <= cnt_us + 1'd1;           //璁℃椂涓嶆弧瓒虫潯浠跺垯缁х画璁℃椂
            end
            START       :begin
                dht11_en <= 1'b1;                      //鍗犵敤鎬荤嚎
                dht11_out <= 1'b0;                     //杈撳嚭浣庣數骞
                if(cnt_us == T_BE)      
                    cnt_us <= 22'd0;                   //璁℃椂婊¤冻鏉′欢鍒欐竻闆
                else        
                    cnt_us <= cnt_us + 1'd1;           //璁℃椂涓嶆弧瓒虫潯浠跺垯缁х画璁℃椂
            end     
            DELAY_10us  :begin      
                dht11_en <= 1'b0;                      //閲婃斁鎬荤嚎锛岀敱澶栭儴鐢甸樆鎷夐珮
                if(cnt_us == T_GO)
                    cnt_us <= 22'd0;                   //璁℃椂婊¤冻鏉′欢鍒欐竻闆
                else                                    
                    cnt_us <= cnt_us + 1'd1;           //璁℃椂涓嶆弧瓒虫潯浠跺垯缁х画璁℃椂
            end 
            REPLY       :begin
                dht11_en <= 1'b0;                      //閲婃斁鎬荤嚎锛岀敱澶栭儴鐢甸樆鎷夐珮
                if(cnt_us <= 'd500)begin               //璁℃椂涓嶅埌500us
                    if(dht11_rise && cnt_us >= 'd70 
                      && cnt_us <= 'd100)              //涓婂崌娌垮搷搴旓紝涓斾綆鐢靛钩鏃堕棿浠嬩簬70~100us
                        cnt_us <= 22'd0;               //璁℃椂娓呴浂
                    else
                        cnt_us <= cnt_us + 1'd1;       //璁℃椂涓嶆弧瓒虫潯浠跺垯缁х画璁℃椂
                end
                else 
                    cnt_us <= 22'd0;                   //瓒呰繃500us浠嶆病鏈変笂鍗囨部鍝嶅簲锛屽垯璁℃暟娓呴浂 
            end 
            DELAY_75us  :begin
                dht11_en <= 1'b0;                      //閲婃斁鎬荤嚎锛岀敱澶栭儴鐢甸樆鎷夐珮
                if(dht11_fall && cnt_us >= 'd70)       //涓婂崌娌垮搷搴旓紝涓斾綆鐢靛钩鏃堕棿澶т簬70us
                    cnt_us <= 22'd0;                   //璁℃椂娓呴浂
                else    
                    cnt_us <= cnt_us + 1'd1;           //璁℃椂涓嶆弧瓒虫潯浠跺垯缁х画璁℃椂
            end
            REV_data    :begin
                dht11_en <= 1'b0;                      //閲婃斁鎬荤嚎锛岀敱澶栭儴鐢甸樆鎷夐珮锛岃繘鍏ヨ鍙栫姸鎬
                if(dht11_rise && bit_cnt == 'd40)begin //鏁版嵁鎺ユ敹瀹屾瘯
                    bit_cnt <=  6'd0;                  //娓呯┖鏁版嵁鎺ユ敹璁℃暟鍣
                    cnt_us <= 22'd0;                   //娓呯┖璁℃椂鍣
                end
                else if(dht11_fall)begin               //妫€娴嬪埌浣庣數骞筹紝鍒欒鏄庢帴鏀跺埌涓€涓暟鎹
                    bit_cnt <= bit_cnt + 1'd1;         //鏁版嵁鎺ユ敹璁℃暟鍣1
                    cnt_us <= 22'd0;                   //璁℃椂鍣ㄩ噸鏂拌鏁
                    if(cnt_us <= 'd100)                
                        data_temp[39-bit_cnt] <= 1'b0; //鎬诲叡鎵€鏈夌殑鏃堕棿灏戜簬100us,鍒欒鏄庢帴鏀跺埌"0"
                    else 
                        data_temp[39-bit_cnt] <= 1'b1; //鎬诲叡鎵€鏈夌殑鏃堕棿澶т簬100us,鍒欒鏄庢帴鏀跺埌"1"
                end
                else begin                             //鎵€鏈夋暟鎹病鏈夋帴鏀跺畬锛屼笖姝ｅ浜涓暟鎹殑鎺ユ敹杩涚▼涓
                    bit_cnt <= bit_cnt;              
                    data_temp <= data_temp;
                    cnt_us <= cnt_us + 1'd1;           //璁℃椂鍣ㄨ鏃
                end
            end
            default:;       
        endcase
end

//鏍￠獙璇诲彇鐨勬暟鎹槸鍚︾鍚堟牎楠岃鍒
always @(posedge clk_us or negedge rst_n)begin
    if(!rst_n) begin
        temp_value <= 8'd0;
        humi_value <= 8'd0;
    end
    else if((data_temp[7:0] == data_temp[39:32] + data_temp[31:24] +
    data_temp[23:16] + data_temp[15:8])) begin
        temp_value <= data_temp[23:16];    //娓╁害鏁存暟閮ㄥ垎
        humi_value <= data_temp[39:32];    //婀垮害鏁存暟閮ㄥ垎
    end
end

// 杈撳嚭褰撳墠鐘舵€
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