# 读取 .c 文件的数据
import re

with open("temp.c", "r") as c_file:
    c_content = c_file.read()

# 删除注释 /* ... */
c_content = re.sub(r"/\*.*?\*/", "", c_content, flags=re.S)

# 提取 gImage_temp 数组数据
data_match = re.search(r"gImage_temp\[\d+\] = \{(.+?)\};", c_content, re.S)
if data_match:
    data_str = data_match.group(1).strip()
    # 转换为列表
    data_list = [x.strip() for x in data_str.split(",") if x.strip()]

# 将数据分组，每组30字节
group_size = 30
data_groups = [data_list[i:i + group_size] for i in range(0, len(data_list), group_size)]

# 构建 Verilog 格式的输出
verilog_lines = []
for i, group in enumerate(data_groups):
    # 转换为 240'h 格式
    hex_value = ''.join(x[2:] for x in group)  # 去掉 '0X'
    verilog_lines.append(f"9'd{i}  : q = 240'h{hex_value:0<60};")  # 补齐到240位

# 输出到 .v 文件
with open("output_pic_ram.v", "w") as v_file:
    v_file.write("\n".join(verilog_lines))

print("转换完成！")
