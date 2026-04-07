



**SHOW** **FULL** **COLUMNS** **FROM** UDMOrganization; 结果如下

| Field                 | Type         | Collation          | Null | Key  | Default | Extra | Privileges                      | Comment |
| --------------------- | ------------ | ------------------ | ---- | ---- | ------- | ----- | ------------------------------- | ------- |
| ID                    | varchar(38)  | utf8mb4_unicode_ci | NO   | PRI  |         |       | select,insert,update,references |         |
| PARENTID              | varchar(38)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| SETID                 | varchar(15)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| DEPTID                | varchar(38)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| FULLNAME              | varchar(90)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| SHORTNAME             | varchar(90)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| EFFECTIVEDATE         | datetime(3)  |                    | YES  |      |         |       | select,insert,update,references |         |
| EFFECTIVESTATUS       | varchar(1)   | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| ISINTREE              | varchar(3)   | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| MANAGERID             | varchar(36)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| MANAGERPOSITIONID     | varchar(36)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| DEPARTMENTCLASS       | varchar(3)   | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| DATASOURCE            | int          |                    | YES  |      |         |       | select,insert,update,references |         |
| FULLPATHCODE          | varchar(500) | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| FULLPATHTEXT          | varchar(500) | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| INNERORDER            | double       |                    | YES  |      |         |       | select,insert,update,references |         |
| DICTORGTYPE           | varchar(38)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| MASTERDATA_BATCHTIME  | datetime(3)  |                    | YES  |      |         |       | select,insert,update,references |         |
| MASTERDATA_DATASTATUS | varchar(1)   | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |
| MASTERDATA_RESULT     | varchar(50)  | utf8mb4_unicode_ci | YES  |      |         |       | select,insert,update,references |         |





**SELECT** * **FROM** UDMOrganization **LIMIT** 3; 结果如下

| ID                                   | PARENTID                             | SETID | DEPTID | FULLNAME     | SHORTNAME    | EFFECTIVEDATE       | EFFECTIVESTATUS | ISINTREE | MANAGERID | MANAGERPOSITIONID                    | DEPARTMENTCLASS | DATASOURCE | FULLPATHCODE                                                 | FULLPATHTEXT                                                 | INNERORDER | DICTORGTYPE | MASTERDATA_BATCHTIME    | MASTERDATA_DATASTATUS | MASTERDATA_RESULT |
| ------------------------------------ | ------------------------------------ | ----- | ------ | ------------ | ------------ | ------------------- | --------------- | -------- | --------- | ------------------------------------ | --------------- | ---------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ---------- | ----------- | ----------------------- | --------------------- | ----------------- |
| 00046A14-BDE2-4D87-874D-2D5C93DF3C38 | CB400274-A1F3-4899-949B-915B7B0B38A3 | 10006 | 103907 | 工程组       | 工程组       | 2020-08-28 00:00:00 | I               | Y        |           | CBDB5A20-3C6E-4377-B3C5-DAB317A44114 |                 | 0          | &#124;&#124;DED0D003-5BC6-494C-8F47-263859F39CF8&#124;&#124;17086695-88C0-4342-AC19-680869B5F779&#124;&#124;65C1C3E0-1E45-4DE0-A646-7C526DF81840&#124;&#124;CB400274-A1F3-4899-949B-915B7B0B38A3&#124;&#124;00046A14-BDE2-4D87-874D-2D5C93DF3C38 | 华夏幸福\物业集团\地产物业京南分公司\永清孔雀城示范区\工程组 | 314853807  |             | 2022-01-20 03:27:32.197 | A                     |                   |
| 00074122-B831-45D9-AAA7-D34966F901E0 | 90398EEF-56E4-43A7-AA06-4724A1E0D0E7 | 10006 | 105050 | 英国宫安全组 | 英国宫安全组 | 2022-02-28 00:00:00 | I               | Y        |           |                                      |                 | 0          | &#124;&#124;DED0D003-5BC6-494C-8F47-263859F39CF8&#124;&#124;17086695-88C0-4342-AC19-680869B5F779&#124;&#124;122C7AFA-12C4-4C28-82B4-20865338D12C&#124;&#124;36FC3B7B-FAB7-4281-A9CE-586CC84B8EB3&#124;&#124;90398EEF-56E4-43A7-AA06-4724A1E0D0E7&#124;&#124;00074122-B831-45D9-AAA7-D34966F901E0 | 华夏幸福\物业集团\香河分公司\香河英国宫片区\大营销\英国宫安全组 | 1008581827 |             | 2022-03-01 03:28:24.317 | A                     |                   |
| 000DE6A1-24E1-4EEF-B949-BBA444FB946D | 8592B53F-E83D-4CD5-BE5B-E10FD04C40CE | 10006 | 111617 | 无锡示范区组 | 无锡示范区组 | 2023-02-21 00:00:00 | I               | Y        |           |                                      |                 | 0          | &#124;&#124;DED0D003-5BC6-494C-8F47-263859F39CF8&#124;&#124;17086695-88C0-4342-AC19-680869B5F779&#124;&#124;DF3E3D19-DC38-4F12-B5E8-56617330E3DB&#124;&#124;8592B53F-E83D-4CD5-BE5B-E10FD04C40CE&#124;&#124;000DE6A1-24E1-4EEF-B949-BBA444FB946D | 华夏幸福\物业集团\溧水分公司\驻无锡机构\无锡示范区组         | 1696628543 |             | 2023-03-30 03:28:43.550 | A                     |                   |