#!/usr/bin/env python3
"""
LumenIM 桌面应用 - 多环境构建脚本 (Python版)
提供跨平台支持和完善的错误处理
"""

import os
import sys
import json
import shutil
import subprocess
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

# ========================================
# 配置
# ========================================

SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent / "front"
LOG_DIR = SCRIPT_DIR / "logs"

# 环境配置
ENV_CONFIGS = {
    "local": {
        "name": "本地开发版",
        "app_title": "LumenIM (本地开发)",
        "app_id": "com.lumenim.desktop.local",
        "product_name": "LumenIM-Local",
        "api_url": "http://localhost:9501",
        "ws_url": "ws://localhost:9502",
        "csp_allow_hosts": "http://localhost:*",
        "csp_allow_ws": "ws://localhost:* wss://localhost:*",
        "debug_mode": "true",
        "log_level": "debug",
        "output_dir": "release_local",
        "vite_mode": "development",
    },
    "test": {
        "name": "测试版",
        "app_title": "LumenIM (测试版)",
        "app_id": "com.lumenim.desktop.test",
        "product_name": "LumenIM-Test",
        "api_url": "http://192.168.23.131:9501",
        "ws_url": "ws://192.168.23.131:9502",
        "csp_allow_hosts": "http://localhost:* http://192.168.23.131:*",
        "csp_allow_ws": "ws://localhost:* wss://localhost:* ws://192.168.23.131:* wss://192.168.23.131:*",
        "debug_mode": "true",
        "log_level": "debug",
        "output_dir": "release_test",
        "vite_mode": "test",
    },
    "prod": {
        "name": "正式版",
        "app_title": "LumenIM",
        "app_id": "com.lumenim.desktop",
        "product_name": "LumenIM",
        "api_url": "https://api.lumenim.com",
        "ws_url": "wss://api.lumenim.com",
        "csp_allow_hosts": "https://api.lumenim.com https://*",
        "csp_allow_ws": "wss://api.lumenim.com:*",
        "debug_mode": "false",
        "log_level": "error",
        "output_dir": "release",
        "vite_mode": "production",
    },
}


# ========================================
# 日志配置
# ========================================

def setup_logging(env: str = "build") -> logging.Logger:
    """配置日志"""
    LOG_DIR.mkdir(exist_ok=True)
    log_file = LOG_DIR / f"build_{env}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    logger = logging.getLogger("LumenIM-Build")
    logger.setLevel(logging.DEBUG)
    
    # 文件处理器
    fh = logging.FileHandler(log_file, encoding="utf-8")
    fh.setLevel(logging.DEBUG)
    
    # 控制台处理器
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    
    # 格式
    formatter = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S"
    )
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    
    logger.addHandler(fh)
    logger.addHandler(ch)
    
    return logger


# ========================================
# 工具函数
# ========================================

def print_step(step: int, total: int, message: str):
    """打印步骤信息"""
    print(f"\n[{step}/{total}] {message}")
    print("=" * 50)


def run_command(cmd: List[str], cwd: Optional[Path] = None, timeout: int = 3600) -> Tuple[int, str, str]:
    """执行命令并返回结果"""
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd or PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace"
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "命令执行超时"
    except Exception as e:
        return -1, "", str(e)


def check_command(cmd: str) -> Tuple[bool, str]:
    """检查命令是否存在"""
    try:
        result = subprocess.run(
            cmd.split() if " " in cmd else [cmd],
            capture_output=True,
            text=True
        )
        version = result.stdout.strip() or result.stderr.strip()
        return True, version
    except Exception:
        return False, ""


# ========================================
# 环境检测
# ========================================

def check_environment(logger: logging.Logger) -> bool:
    """检查构建环境"""
    print("\n" + "=" * 50)
    print("  环境检测")
    print("=" * 50)
    
    checks = [
        ("Node.js", "node --version"),
        ("npm", "npm --version"),
        ("Rust", "rustc --version"),
        ("Cargo", "cargo --version"),
        ("Tauri CLI", "tauri --version"),
    ]
    
    all_passed = True
    
    for name, cmd in checks:
        found, version = check_command(cmd.split()[0])
        if found:
            logger.info(f"{name}: OK ({version.splitlines()[0] if version else '已安装'})")
            print(f"  [OK] {name}")
        else:
            logger.error(f"{name}: 未安装")
            print(f"  [FAIL] {name} - 未安装")
            all_passed = False
    
    # 检查项目文件
    required_files = [
        PROJECT_ROOT / "package.json",
        PROJECT_ROOT / "vite.config.ts",
        PROJECT_ROOT / "src-tauri" / "tauri.conf.json",
        PROJECT_ROOT / "src-tauri" / "Cargo.toml",
    ]
    
    for file in required_files:
        if file.exists():
            logger.info(f"文件存在: {file.name}")
            print(f"  [OK] {file.name}")
        else:
            logger.error(f"文件缺失: {file}")
            print(f"  [FAIL] {file.name} - 文件缺失")
            all_passed = False
    
    return all_passed


def install_dependencies(logger: logging.Logger) -> bool:
    """安装依赖"""
    print_step(1, 3, "安装依赖")
    
    logger.info("安装前端依赖...")
    code, stdout, stderr = run_command(["npm", "install"], PROJECT_ROOT)
    
    if code == 0:
        logger.info("前端依赖安装成功")
        print("  [OK] npm install")
        return True
    else:
        logger.error(f"npm install 失败: {stderr}")
        print(f"  [FAIL] npm install")
        print(f"  错误: {stderr[:200]}")
        return False


# ========================================
# 配置生成
# ========================================

def generate_env_file(env: str, config: Dict, logger: logging.Logger) -> bool:
    """生成 .env 文件"""
    env_file = PROJECT_ROOT / f".env.{env}"
    
    content = f'''# LumenIM 环境配置 - {config["name"]}
# 生成时间: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

VITE_APP_ENV={env}
VITE_APP_TITLE={config["app_title"]}
VITE_BASE=/

# API 配置
VITE_BASE_API={config["api_url"]}
VITE_SOCKET_API={config["ws_url"]}

# 功能开关
VITE_ENABLE_DEBUG={config["debug_mode"]}
VITE_ENABLE_MOCK=false
VITE_ENABLE_ANALYTICS={config["debug_mode"]}

# 日志级别
VITE_LOG_LEVEL={config["log_level"]}
'''
    
    try:
        env_file.write_text(content, encoding="utf-8")
        logger.info(f"环境配置文件已生成: {env_file}")
        return True
    except Exception as e:
        logger.error(f"生成环境配置文件失败: {e}")
        return False


def generate_tauri_config(env: str, config: Dict, logger: logging.Logger) -> bool:
    """生成 Tauri 配置文件"""
    config_file = PROJECT_ROOT / "src-tauri" / f"tauri.conf.{env}.json"
    
    tauri_config = {
        "$schema": "../../node_modules/@tauri-apps/cli/config.schema.json",
        "productName": config["product_name"],
        "version": "1.0.0",
        "identifier": config["app_id"],
        "build": {
            "frontendDist": "../dist",
            "devUrl": "http://localhost:5173",
            "beforeDevCommand": "npm run dev",
            "beforeBuildCommand": ""
        },
        "app": {
            "withGlobalTauri": True,
            "windows": [{
                "title": config["app_title"],
                "width": 1200,
                "height": 800,
                "minWidth": 800,
                "minHeight": 600,
                "resizable": True,
                "fullscreen": False,
                "center": True
            }],
            "security": {
                "csp": (
                    f"default-src 'self' {config['csp_allow_hosts']}; "
                    f"script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
                    f"style-src 'self' 'unsafe-inline'; "
                    f"img-src 'self' data: blob: asset: {config['csp_allow_hosts']}; "
                    f"font-src 'self' data:; "
                    f"connect-src 'self' ipc: {config['csp_allow_hosts']} https://* {config['csp_allow_ws']} ws://* wss://*; "
                    f"frame-src 'self' blob:; "
                    f"media-src 'self' blob: {config['csp_allow_hosts']}; "
                    f"object-src 'self' blob:"
                )
            }
        },
        "bundle": {
            "active": True,
            "targets": ["nsis"],
            "icon": [
                "icons/32x32.png",
                "icons/128x128.png",
                "icons/128x128@2x.png",
                "icons/icon.icns",
                "icons/icon.ico"
            ],
            "windows": {
                "nsis": {
                    "installMode": "currentUser"
                }
            }
        }
    }
    
    try:
        config_file.write_text(json.dumps(tauri_config, indent=2, ensure_ascii=False), encoding="utf-8")
        logger.info(f"Tauri 配置文件已生成: {config_file}")
        return True
    except Exception as e:
        logger.error(f"生成 Tauri 配置文件失败: {e}")
        return False


# ========================================
# 构建
# ========================================

def build_frontend(env: str, config: Dict, logger: logging.Logger) -> bool:
    """构建前端"""
    logger.info(f"构建前端 (模式: {config['vite_mode']})")
    
    # 复制配置
    tauri_config_src = PROJECT_ROOT / "src-tauri" / f"tauri.conf.{env}.json"
    tauri_config_dst = PROJECT_ROOT / "src-tauri" / "tauri.conf.json"
    
    if tauri_config_src.exists():
        shutil.copy(tauri_config_src, tauri_config_dst)
        logger.info("Tauri 配置已应用")
    
    # 构建前端
    code, stdout, stderr = run_command(
        ["npm", "run", "build", "--", "--mode", config["vite_mode"]],
        PROJECT_ROOT
    )
    
    if code == 0:
        logger.info("前端构建成功")
        print("  [OK] 前端构建完成")
        return True
    else:
        logger.error(f"前端构建失败: {stderr}")
        print(f"  [FAIL] 前端构建失败")
        return False


def build_tauri(config: Dict, logger: logging.Logger) -> bool:
    """构建 Tauri 应用"""
    logger.info("构建 Tauri 应用...")
    
    # 清理旧构建
    output_dir = PROJECT_ROOT / "src-tauri" / "target" / config["output_dir"]
    if output_dir.exists():
        shutil.rmtree(output_dir)
        logger.info(f"已清理旧构建目录: {output_dir}")
    
    # 构建
    code, stdout, stderr = run_command(
        ["npx", "tauri", "build"],
        PROJECT_ROOT,
        timeout=7200  # 2小时超时
    )
    
    if code == 0:
        logger.info("Tauri 构建成功")
        print("  [OK] Tauri 构建完成")
        return True
    else:
        logger.error(f"Tauri 构建失败: {stderr}")
        print(f"  [FAIL] Tauri 构建失败")
        return False


def move_artifacts(env: str, config: Dict, logger: logging.Logger) -> bool:
    """移动构建产物"""
    src_dir = PROJECT_ROOT / "src-tauri" / "target" / "release"
    dst_dir = PROJECT_ROOT / "src-tauri" / "target" / config["output_dir"]
    
    logger.info(f"移动构建产物到: {dst_dir}")
    
    try:
        dst_dir.mkdir(parents=True, exist_ok=True)
        
        # 复制可执行文件
        exe_file = src_dir / "lumenim-desktop.exe"
        if exe_file.exists():
            shutil.copy(exe_file, dst_dir / "lumenim-desktop.exe")
        
        # 复制安装包
        bundle_dir = src_dir / "bundle"
        if bundle_dir.exists():
            dst_bundle = dst_dir / "bundle"
            if dst_bundle.exists():
                shutil.rmtree(dst_bundle)
            shutil.copytree(bundle_dir, dst_bundle)
        
        logger.info("构建产物移动完成")
        return True
    except Exception as e:
        logger.error(f"移动构建产物失败: {e}")
        return False


def build_environment(env: str, logger: logging.Logger) -> bool:
    """构建指定环境"""
    if env not in ENV_CONFIGS:
        logger.error(f"未知环境: {env}")
        print(f"[FAIL] 未知环境: {env}")
        return False
    
    config = ENV_CONFIGS[env]
    
    print(f"\n{'=' * 50}")
    print(f"  构建环境: {config['name']}")
    print(f"{'=' * 50}")
    
    logger.info(f"========================================")
    logger.info(f"开始构建环境: {config['name']} ({env})")
    logger.info(f"========================================")
    
    # 生成配置文件
    print_step(1, 4, "生成配置文件")
    if not generate_env_file(env, config, logger):
        return False
    if not generate_tauri_config(env, config, logger):
        return False
    
    # 构建前端
    print_step(2, 4, "构建前端")
    if not build_frontend(env, config, logger):
        return False
    
    # 构建 Tauri
    print_step(3, 4, "构建 Tauri")
    if not build_tauri(config, logger):
        return False
    
    # 移动产物
    print_step(4, 4, "移动构建产物")
    if not move_artifacts(env, config, logger):
        return False
    
    # 显示结果
    output_dir = PROJECT_ROOT / "src-tauri" / "target" / config["output_dir"]
    exe_file = output_dir / "lumenim-desktop.exe"
    
    print(f"\n{'=' * 50}")
    print(f"  {config['name']} 构建结果")
    print(f"{'=' * 50}")
    
    if exe_file.exists():
        size_mb = exe_file.stat().st_size / (1024 * 1024)
        print(f"  可执行文件: {exe_file}")
        print(f"  文件大小: {size_mb:.2f} MB")
    
    # 查找安装包
    nsis_dir = output_dir / "bundle" / "nsis"
    if nsis_dir.exists():
        for f in nsis_dir.glob("*.exe"):
            size_mb = f.stat().st_size / (1024 * 1024)
            print(f"  安装包: {f.name}")
            print(f"  安装包大小: {size_mb:.2f} MB")
    
    print(f"{'=' * 50}")
    
    logger.info(f"环境 {env} 构建完成!")
    return True


# ========================================
# 主函数
# ========================================

def main():
    print("\n" + "=" * 50)
    print("  LumenIM 桌面应用 - 多环境构建脚本")
    print("=" * 50)
    
    # 解析参数
    env = sys.argv[1] if len(sys.argv) > 1 else "local"
    
    if env == "--help" or env == "-h":
        print("\n用法: python build.py [环境]")
        print("\n可用环境:")
        print("  local    - 本地开发版 (默认)")
        print("  test     - 测试版")
        print("  prod     - 正式版")
        print("  all      - 构建所有版本")
        print("  check    - 仅检查环境")
        print("\n示例:")
        print("  python build.py local")
        print("  python build.py test")
        print("  python build.py prod")
        print("  python build.py all")
        print("  python build.py check")
        return 0
    
    # 设置日志
    logger = setup_logging(env)
    
    # 环境检测
    if env == "check":
        success = check_environment(logger)
        return 0 if success else 1
    
    # 检查环境
    if not check_environment(logger):
        print("\n[ERROR] 环境检测失败，请先安装必要依赖")
        return 1
    
    # 安装依赖
    if not install_dependencies(logger):
        print("\n[ERROR] 依赖安装失败")
        return 1
    
    # 构建
    if env == "all":
        results = {}
        for e in ["local", "test", "prod"]:
            print(f"\n{'#' * 60}")
            print(f"### 构建环境 {e}")
            print(f"{'#' * 60}")
            results[e] = build_environment(e, logger)
        
        print(f"\n{'=' * 50}")
        print("  全环境构建结果汇总")
        print(f"{'=' * 50}")
        
        for e, success in results.items():
            config = ENV_CONFIGS[e]
            status = "成功" if success else "失败"
            print(f"  {config['name']}: {status}")
        
        print(f"{'=' * 50}")
        
        if all(results.values()):
            logger.info("所有环境构建完成")
            print("\n所有环境构建成功!")
        else:
            logger.error("部分环境构建失败")
            print("\n部分环境构建失败，请查看日志")
            return 1
    else:
        success = build_environment(env, logger)
        if success:
            logger.info(f"构建完成: {env}")
            print(f"\n[SUCCESS] {ENV_CONFIGS[env]['name']} 构建成功!")
            return 0
        else:
            logger.error(f"构建失败: {env}")
            print(f"\n[FAIL] {ENV_CONFIGS[env]['name']} 构建失败!")
            return 1


if __name__ == "__main__":
    sys.exit(main())
