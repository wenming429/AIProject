# LumenIM Desktop Build Scripts

## Scripts

| Script | Description |
|--------|-------------|
| `build-check.bat` | Check build environment |
| `build-local.bat` | Build local version |
| `build-test.bat` | Build test version |
| `build-prod.bat` | Build production version |
| `build-all.bat` | Build all environments |
| `build-tauri.bat` | Core build script (used by others) |

## Usage

### Check Environment
```batch
build-check.bat
```

### Build Single Environment
```batch
build-local.bat   # Local dev
build-test.bat   # Test
build-prod.bat   # Production
```

### Build All
```batch
build-all.bat
```

## Output Locations

| Environment | Path |
|-------------|------|
| Local | `front/src-tauri/target/release_local` |
| Test | `front/src-tauri/target/release_test` |
| Production | `front/src-tauri/target/release` |

## Environment Config

| Setting | Local | Test | Production |
|---------|-------|------|------------|
| API | localhost:9501 | 192.168.23.131:9501 | api.lumenim.com |
| WebSocket | ws://localhost:9502 | ws://192.168.23.131:9502 | wss://api.lumenim.com |
| App ID | com.lumenim.desktop.local | com.lumenim.desktop.test | com.lumenim.desktop |
