@echo off
chcp 65001 >nul
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -pwenming429 go_chat -e "DROP DATABASE IF EXISTS go_chat; CREATE DATABASE go_chat CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -pwenming429 go_chat < "d:\学习资料\AI_Projects\LumenIM\backend\sql\lumenim.sql"
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -pwenming429 go_chat < "d:\学习资料\AI_Projects\LumenIM\test_data.sql"
echo 数据库已重新导入完成！
pause
