@echo off
cd /d "d:\学习资料\AI_Projects\LumenIM\scripts"
mysql -u root -pwenming429 go_chat -e "SELECT COUNT(*) FROM organize_dept;"
