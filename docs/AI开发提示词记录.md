# AI开发提示词记录

**关于CentOS 7系统服务部署下载离线安装包**

> ​	**针对CentOS 7系统无法访问外网的服务器环境，生成完整的离线部署方案。**
>
> 1. 首先列出Linux环境所需的软件包清单，涵盖基础依赖及常用组件。详细说明环境准备步骤，包括依赖包下载、介质制作及上传方法。
> 2. 提供软件安装的具体指令，确保所有依赖关系正确解析。阐述服务配置流程，包括配置文件修改、权限设置及环境变量配置。
>
> 最后编写服务启动、停止及开机自启的脚本命令，确保整个离线部署过程流畅且可复现。



```SH
# 1. 下载离线包
cd software/scripts
./download-offline.sh /tmp/packages

# 2. 打包 Docker 镜像
docker save -o mysql-8.0.35.tar mysql:8.0.35
docker save -o redis-7.4.1.tar redis:7.4.1

# 3. 打包项目
tar --exclude='node_modules' -czf front.tar.gz front/

# 4. 复制到 U 盘
cp -r /tmp/packages/* /mnt/usb/

```

