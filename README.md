# System Uptime Calculator

A PowerShell script that calculates your computer's total uptime over the last 365 days by analyzing Windows Event Log boot and shutdown events.

## Features

- Analyzes Windows Event Log entries (Event IDs: 6005, 6006, 6008, 6009)
- Calculates cumulative uptime across all sessions
- Shows total uptime in days, hours, and minutes
- Displays uptime percentage for the last 365 days
- Automatically generates event log data if needed

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Administrator privileges (recommended for accessing event logs)

## Usage

### Method 1: Run directly from PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\calculate_uptime.ps1
```

### Method 2: Run from PowerShell ISE or Terminal

1. Open PowerShell
2. Navigate to the script directory
3. Run: `.\calculate_uptime.ps1`

If you get an execution policy error, run:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Method 3: Right-click and "Run with PowerShell"

1. Right-click on `calculate_uptime.ps1`
2. Select "Run with PowerShell"

## How It Works

1. The script queries Windows Event Log for boot/shutdown events (Event IDs 6005, 6006, 6008, 6009)
2. If the events file doesn't exist, it automatically generates one using `wevtutil`
3. Parses events from the last 365 days
4. Calculates uptime by tracking boot → shutdown pairs
5. Displays comprehensive statistics including:
   - Total number of sessions
   - Total uptime in days, hours, minutes
   - Uptime percentage

## Event IDs Explained

- **6005**: Event log service started (system boot)
- **6006**: Event log service stopped (system shutdown)
- **6008**: Unexpected shutdown detected
- **6009**: System startup detected

## Example Output

```
==========================================
System Uptime Analysis (Last 365 Days)
==========================================
Analysis Period: 12/18/2024 13:49:40 to 12/18/2025 13:49:40

Found 291 boot/shutdown events in the last 365 days

==========================================
RESULTS
==========================================
Total Sessions: 194

Total Uptime:
  Days: 134
  Hours: 0
  Minutes: 39
  Total Hours: 3216.66
  Total Days: 134.03

Uptime Percentage: 36.72%
==========================================
```

## Troubleshooting

### "Events file not found" or "Could not generate events file"

- Ensure you're running PowerShell as Administrator
- Check that Windows Event Log service is running
- Verify you have read permissions on the System event log

### "Execution Policy" errors

Run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### No events found

- Your event log may not contain data going back 365 days
- The script will show current session uptime as a fallback

## License

This project is provided as-is for personal and educational use.

## Version

v1.0.0.0

