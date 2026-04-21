[root@imtest01 docker]# rpm -Uvh --force *.rpm
警告：containerd.io-1.6.33-3.1.el7.x86_64.rpm: 头V4 RSA/SHA512 Signature, 密钥 ID 621e9f35: NOKEY
警告：container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm: 头V3 RSA/SHA256 Signature, 密钥 ID f4a80eb5: NOKEY
警告：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64.rpm: 头V3 RSA/SHA256 Signature, 密钥 ID 8483c65d: NOKEY
错误：依赖检测失败：
        fuse3 被 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
        libc.so.6(GLIBC_2.28)(64bit) 被 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
        libfuse3.so.3()(64bit) 被 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
        libfuse3.so.3(FUSE_3.0)(64bit) 被 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
        libfuse3.so.3(FUSE_3.2)(64bit) 被 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
        libslirp.so.0()(64bit) 被 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
        libslirp.so.0(SLIRP_4.0)(64bit) 被 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
        libslirp.so.0(SLIRP_4.1)(64bit) 被 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
[root@imtest01 docker]# yum localinstall -y *.rpm
已加载插件：fastestmirror, langpacks
正在检查 containerd.io-1.6.33-3.1.el7.x86_64.rpm: containerd.io-1.6.33-3.1.el7.x86_64
containerd.io-1.6.33-3.1.el7.x86_64.rpm 将被安装
正在检查 container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm: 2:container-selinux-2.119.2-1.911c772.el7_8.noarch
container-selinux-2.119.2-1.911c772.el7_8.noarch.rpm 将被安装
正在检查 docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm: docker-buildx-plugin-0.12.1-1.el7.x86_64
docker-buildx-plugin-0.12.1-1.el7.x86_64.rpm 将被安装
正在检查 docker-ce-26.1.4-1.el7.x86_64.rpm: 3:docker-ce-26.1.4-1.el7.x86_64
docker-ce-26.1.4-1.el7.x86_64.rpm 将被安装
正在检查 docker-ce-cli-26.1.4-1.el7.x86_64.rpm: 1:docker-ce-cli-26.1.4-1.el7.x86_64
docker-ce-cli-26.1.4-1.el7.x86_64.rpm 将被安装
正在检查 docker-ce-rootless-extras-26.1.4-1.el7.x86_64.rpm: docker-ce-rootless-extras-26.1.4-1.el7.x86_64
docker-ce-rootless-extras-26.1.4-1.el7.x86_64.rpm 将被安装
正在检查 docker-compose-plugin-2.24.5-1.el7.x86_64.rpm: docker-compose-plugin-2.24.5-1.el7.x86_64
docker-compose-plugin-2.24.5-1.el7.x86_64.rpm 将被安装
正在检查 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64.rpm: fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64
fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64.rpm 将被安装
正在检查 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64.rpm: slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64
slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64.rpm 将被安装
正在解决依赖关系
--> 正在检查事务
---> 软件包 container-selinux.noarch.2.2.119.2-1.911c772.el7_8 将被 安装
---> 软件包 containerd.io.x86_64.0.1.6.33-3.1.el7 将被 安装
---> 软件包 docker-buildx-plugin.x86_64.0.0.12.1-1.el7 将被 安装
---> 软件包 docker-ce.x86_64.3.26.1.4-1.el7 将被 安装
---> 软件包 docker-ce-cli.x86_64.1.26.1.4-1.el7 将被 安装
---> 软件包 docker-ce-rootless-extras.x86_64.0.26.1.4-1.el7 将被 安装
---> 软件包 docker-compose-plugin.x86_64.0.2.24.5-1.el7 将被 安装
---> 软件包 fuse-overlayfs.x86_64.0.1.4.0-2.module_el8.5.0+736+58cc1a5a 将被 安装
--> 正在处理依赖关系 fuse3，它被软件包 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
Determining fastest mirrors
base                                                                                                                                                                                            | 2.9 kB  00:00:00     
updates                                                                                                                                                                                         | 2.9 kB  00:00:00     
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
http://repo.zabbix.com/non-supported/rhel/7/x86_64/repodata/repomd.xml: [Errno 14] curl#7 - "Failed to connect to 2604:a880:2:d0::2062:d001: 网络不可达"
正在尝试其它镜像。
--> 正在处理依赖关系 libc.so.6(GLIBC_2.28)(64bit)，它被软件包 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
--> 正在处理依赖关系 libfuse3.so.3(FUSE_3.0)(64bit)，它被软件包 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
--> 正在处理依赖关系 libfuse3.so.3(FUSE_3.2)(64bit)，它被软件包 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
--> 正在处理依赖关系 libfuse3.so.3()(64bit)，它被软件包 fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 需要
---> 软件包 slirp4netns.x86_64.0.1.1.8-1.module_el8.5.0+877+1c30e0c9 将被 安装
--> 正在处理依赖关系 libslirp.so.0(SLIRP_4.0)(64bit)，它被软件包 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
--> 正在处理依赖关系 libslirp.so.0(SLIRP_4.1)(64bit)，它被软件包 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
--> 正在处理依赖关系 libslirp.so.0()(64bit)，它被软件包 slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 需要
--> 解决依赖关系完成
错误：软件包：slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 (/slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64)
          需要：libslirp.so.0(SLIRP_4.1)(64bit)
错误：软件包：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 (/fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64)
          需要：libfuse3.so.3(FUSE_3.0)(64bit)
错误：软件包：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 (/fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64)
          需要：libfuse3.so.3()(64bit)
错误：软件包：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 (/fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64)
          需要：libc.so.6(GLIBC_2.28)(64bit)
错误：软件包：slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 (/slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64)
          需要：libslirp.so.0()(64bit)
错误：软件包：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 (/fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64)
          需要：fuse3
错误：软件包：slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64 (/slirp4netns-1.1.8-1.module_el8.5.0+877+1c30e0c9.x86_64)
          需要：libslirp.so.0(SLIRP_4.0)(64bit)
错误：软件包：fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64 (/fuse-overlayfs-1.4.0-2.module_el8.5.0+736+58cc1a5a.x86_64)
          需要：libfuse3.so.3(FUSE_3.2)(64bit)
 您可以尝试添加 --skip-broken 选项来解决该问题
 您可以尝试执行：rpm -Va --nofiles --nodigest
