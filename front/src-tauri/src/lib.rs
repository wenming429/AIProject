/// 启用调试模式 - 可通过环境变量或命令行参数控制
fn is_debug_mode() -> bool {
    #[cfg(debug_assertions)]
    {
        true
    }
    #[cfg(not(debug_assertions))]
    {
        std::env::var("LUMENIM_DEBUG").is_ok()
    }
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // 在 debug 模式下启用日志插件
    let log_plugin = tauri_plugin_log::Builder::default()
        .level(log::LevelFilter::Debug)
        .build();

    tauri::Builder::default()
        .plugin(log_plugin)
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_fs::init())
        .plugin(tauri_plugin_os::init())
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            Some(vec!["--minimized"]),
        ))
        .plugin(tauri_plugin_window_state::Builder::default().build())
        .plugin(tauri_plugin_http::init())
        .invoke_handler(tauri::generate_handler![
            get_app_version,
            get_system_info,
            minimize_window,
            maximize_window,
            close_window,
            toggle_maximize,
            is_maximized,
            open_devtools_cmd,
            get_debug_info,
            log_message,
        ])
        .setup(|_app| {
            #[cfg(debug_assertions)]
            {
                use tauri::Manager;
                let window = _app.get_webview_window("main").unwrap();
                if is_debug_mode() {
                    log::info!("Debug mode enabled - opening DevTools");
                    window.open_devtools();
                }
            }
            #[cfg(not(debug_assertions))]
            let _ = _app;
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

// ============ 基础命令 ============

#[tauri::command]
fn get_app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[tauri::command]
fn get_system_info() -> serde_json::Value {
    serde_json::json!({
        "os": std::env::consts::OS,
        "arch": std::env::consts::ARCH,
        "debug": is_debug_mode(),
        "version": env!("CARGO_PKG_VERSION"),
    })
}

// ============ 窗口控制命令 ============

#[tauri::command]
fn minimize_window(window: tauri::Window) {
    let _ = window.minimize();
}

#[tauri::command]
fn maximize_window(window: tauri::Window) {
    let _ = window.maximize();
}

#[tauri::command]
fn toggle_maximize(window: tauri::Window) {
    if window.is_maximized().unwrap_or(false) {
        let _ = window.unmaximize();
    } else {
        let _ = window.maximize();
    }
}

#[tauri::command]
fn close_window(window: tauri::Window) {
    let _ = window.close();
}

#[tauri::command]
fn is_maximized(window: tauri::Window) -> bool {
    window.is_maximized().unwrap_or(false)
}

// ============ 调试命令 ============

#[tauri::command]
fn open_devtools_cmd(window: tauri::Window) {
    #[cfg(debug_assertions)]
    {
        window.open_devtools();
    }
    #[cfg(not(debug_assertions))]
    {
        let _ = window; // 避免未使用警告
        log::warn!("DevTools only available in debug builds");
    }
}

#[tauri::command]
fn get_debug_info() -> serde_json::Value {
    serde_json::json!({
        "debug_mode": is_debug_mode(),
        "version": env!("CARGO_PKG_VERSION"),
        "rust_version": option_env!("BUILD_RUST_VERSION").unwrap_or("unknown"),
        "features": {
            "log_plugin": true,
            "shell_plugin": true,
            "dialog_plugin": true,
            "notification_plugin": true,
            "clipboard_plugin": true,
            "fs_plugin": true,
            "os_plugin": true,
            "process_plugin": true,
            "autostart_plugin": true,
            "window_state_plugin": true,
        }
    })
}

#[tauri::command]
fn log_message(level: String, message: String) {
    match level.as_str() {
        "error" => log::error!("[Frontend] {}", message),
        "warn" => log::warn!("[Frontend] {}", message),
        "info" => log::info!("[Frontend] {}", message),
        "debug" => log::debug!("[Frontend] {}", message),
        _ => log::info!("[Frontend] {}", message),
    }
}
