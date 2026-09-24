# IDM Toolkit

**IDM — Activation & Utility**  
*Version 3.6 | PowerShell & WPF Edition*

---

## 🌟 Overview

**IDM Toolkit** is an all-in-one management, recovery, and configuration utility for Internet Download Manager (IDM). Built with native Windows PowerShell and a WPF Graphical User Interface modeled after the original IDM interface, it provides lifetime trial freezing, registration activation, clean environment reset, and JSON settings backup/restore.

---

- **Trial Period Freeze**: Locks registry trial keys for perpetual evaluation without trigger popups.
- **License Activation**: Generates registration tokens and locks CLSID registry references.
- **Clean Wipe & Reset**: Clears all activation data, keys, and registry locks to return IDM to a fresh 30-day state.
- **JSON Backup & Restore**: Exports download categories, connection speeds, and configurations to JSON backup files for easy migration and recovery.
- **Structured File Logging**: Automatic timestamped log file generation with auto-rotation (`IDM-Toolkit.log`).
- **Automated Unit Testing**: Includes a Pester test suite (`IDM-Toolkit.Tests.ps1`) compatible with Pester v3, v4, and v5.

---

## 🚀 Quick Start

### Option 1 — Graphical Interface (Recommended)
Double-click **`Run-IDM-Toolkit.cmd`**.  
*(Automatically prompts for UAC Administrator privileges and starts in WPF `-STA` mode.)*

### Option 2 — PowerShell Command Line
```powershell
# Open default Graphical Interface
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1

# Launch directly into GUI mode
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Gui
```

### Option 3 — Headless / Unattended Execution
```powershell
# Freeze trial period
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Mode trial

# Activate license
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Mode license

# Perform clean reset
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Mode wipe

# Export settings to JSON backup
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Mode backup

# Import settings from JSON backup
powershell -ExecutionPolicy Bypass -File .\IDM-Toolkit.ps1 -Mode restore
```

---

## 📂 Project Structure

```
├── Run-IDM-Toolkit.cmd     # Double-click UAC launcher
├── IDM-Toolkit.ps1         # Core engine & backend logic
├── IDM-Toolkit-GUI.ps1     # Native WPF Graphical Interface
├── IDM-Toolkit.Tests.ps1   # Pester unit test suite
├── README.md               # Documentation
├── LICENSE                 # MIT License
└── .gitignore              # Git ignore rules
```

---

## 🧪 Running Unit Tests

Run the included Pester test suite to verify file syntax, JSON serialization, log engine, and regex validators:

```powershell
powershell -ExecutionPolicy Bypass -Command "Invoke-Pester -Path .\IDM-Toolkit.Tests.ps1"
```

---

## 📜 License

This project is released into the public domain under [The Unlicense](LICENSE).
