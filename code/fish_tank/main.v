module main(
	input clk,          // System clock input
	input mq2_data,     // MQ-2 sensor data input
	inout dht11_data,   // DHT11 sensor data input
	inout max30102_sda, // MAX30102 I2C data line
	output max30102_scl, // MAX30102 I2C clock line
	output [3:0]state,
	output buzzer,      // Buzzer output (active low)
	output wave_out,    // 25kHz PWM output for fan
	output [7:0] device_id_out,  // MAX30102璁惧ID杈撳嚭
	output [15:0] spo2_data,     // 琛€姘ф暟鎹緭鍑
	output spo2_data_valid,      // 琛€姘ф暟鎹湁鏁堟爣蹇
	input key_in,               // 鎸夐敭杈撳叆
	input intr,                 // MAX30102涓柇淇″彿
	output uart_tx              // UART鍙戦€佸紩鑴
);

	// Internal signal definition
	wire rst_n;         // System reset signal, active low
	wire max30102_init_done;  // MAX30102鍒濆鍖栧畬鎴愭爣蹇
	wire [7:0] max30102_debug;  // MAX30102璋冭瘯淇℃伅
	wire [7:0] max30102_device_id; // MAX30102璁惧ID
	
	// 琛€姘у鐞嗙浉鍏充俊鍙
	wire [35:0] temp_data;        // 琛€姘у師濮嬫暟鎹
	wire temp_data_de;            // 琛€姘ф暟鎹湁鏁堟爣蹇
	wire [3:0] led;               // LED鎸囩ず鐏
	
	// 灏嗗唴閮ㄨ澶嘔D杩炴帴鍒拌緭鍑
	assign device_id_out = max30102_device_id;

	// Reset module instantiation
	rst_module rst_inst(
		.clk(clk),
		.rst_n(rst_n)
	);

	// DHT11 sensor control module instantiation
	dht11_module dht11_inst(
		.sys_clk(clk),
		.rst_n(!rst_n),
		.dht11(dht11_data),
		.state(state),
		.temp_value(temp_value),
		.humi_value(humi_value)
	);

	// Alarm control module instantiation
	alarm_ctrl alarm_inst(
		.clk(clk),
		.rst_n(rst_n),
		.mq2_data(mq2_data),
		.temperature(temp_value),
		.buzzer_out(buzzer),
		.wave_out(wave_out)
	);


	// 琛€姘у鐞嗘ā鍧楀疄渚嬪寲
	spo spo_inst(
		.clk(clk),
		.rst_n(rst_n),
		.spodata(temp_data),
		.spodata_de(temp_data_de),
		.spodata_out(spo2_data),
		.spodata_out_en(spo2_data_valid)
	);
	
	// 闆嗘垚temp鐩綍涓殑椤跺眰妯″潡
	top_temp u_top_temp(
		.clk(clk),
		.rst_n(rst_n),
		.temp_data(temp_data),
		.temp_data_de(temp_data_de),
		.iic_0_scl(max30102_scl),  // 涓嶈繛鎺ワ紝浣跨敤max30102_controller
		.iic_0_sda(max30102_sda),  // 涓嶈繛鎺ワ紝浣跨敤max30102_controller
		.intr(intr)
	);
	
	// 娣诲姞UART璋冭瘯杈撳嚭
	debug_uart_tx #(
		.CLK_FRE(50),
		.BAUD_RATE(115200)
	) u_debug_uart_tx(
		.clk(clk),
		.rst_n(rst_n),
		.datain({6'd0, temp_data[35:18], 6'd0, temp_data[17:0]}),
		.data_de(temp_data_de),
		.uart_tx(uart_tx)
	);

endmodule