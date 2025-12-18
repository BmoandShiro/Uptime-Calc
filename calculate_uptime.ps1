# Function to get time frame from user
function Get-TimeFrame {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "System Uptime Calculator"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "Select time frame for analysis:"
    Write-Host "  1. Last 7 days"
    Write-Host "  2. Last 30 days"
    Write-Host "  3. Last 90 days"
    Write-Host "  4. Last 180 days"
    Write-Host "  5. Last 365 days (1 year) [DEFAULT]"
    Write-Host "  6. Custom number of days"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1-6, or press Enter for default 1 year)"
    
    # Default to 365 days if Enter is pressed
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $days = 365
        Write-Host "Using default: 365 days (1 year)" -ForegroundColor Green
        return $days
    }
    
    switch ($choice) {
        "1" { return 7 }
        "2" { return 30 }
        "3" { return 90 }
        "4" { return 180 }
        "5" { return 365 }
        "6" {
            while ($true) {
                $customDays = Read-Host "Enter number of days (1-3650)"
                if ($customDays -match '^\d+$' -and [int]$customDays -ge 1 -and [int]$customDays -le 3650) {
                    return [int]$customDays
                } else {
                    Write-Host "Invalid input. Please enter a number between 1 and 3650." -ForegroundColor Red
                }
            }
        }
        default {
            Write-Host "Invalid choice. Using default: 365 days (1 year)" -ForegroundColor Yellow
            return 365
        }
    }
}

# Get time frame from user
$days = Get-TimeFrame
$endDate = Get-Date
$startDate = $endDate.AddDays(-$days)

Write-Host ""
Write-Host "=========================================="
if ($days -eq 365) {
    Write-Host "System Uptime Analysis (Last 365 Days / 1 Year)"
} else {
    Write-Host "System Uptime Analysis (Last $days Days)"
}
Write-Host "=========================================="
Write-Host "Analysis Period: $startDate to $endDate"
Write-Host ""

$eventsFile = "$env:TEMP\events.txt"
if (-not (Test-Path $eventsFile)) {
    Write-Host "Events file not found. Generating from Windows Event Log..."
    Write-Host "This may take a few moments..."
    wevtutil qe System /c:1000 /rd:true /f:text /q:"*[System[(EventID=6005 or EventID=6006 or EventID=6008 or EventID=6009)]]" | Out-File -FilePath $eventsFile -Encoding UTF8
    if (-not (Test-Path $eventsFile)) {
        Write-Host "Error: Could not generate events file. Please ensure you have administrator privileges."
        Write-Host ""
        Write-Host "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit 1
    }
    Write-Host "Events file generated successfully."
    Write-Host ""
}

# Parse events from file
$events = @()
$content = Get-Content $eventsFile -Raw
$eventBlocks = $content -split 'Event\['

foreach ($block in $eventBlocks) {
    if ($block -match 'Event ID: (\d+)') {
        $eventId = [int]$matches[1]
        if ($block -match 'Date: ([0-9TZ:.-]+)') {
            $dateStr = $matches[1]
            if ($eventId -in @(6005, 6006, 6008, 6009)) {
                try {
                    $eventDate = [DateTime]::Parse($dateStr)
                    if ($eventDate -ge $startDate -and $eventDate -le $endDate) {
                        $events += [PSCustomObject]@{
                            EventID = $eventId
                            TimeCreated = $eventDate
                        }
                    }
                } catch {
                    # Skip invalid dates
                }
            }
        }
    }
}

if ($events.Count -eq 0) {
    Write-Host "No boot/shutdown events found in the last $days days."
    Write-Host "Checking current session uptime..."
    $lastBoot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $currentUptime = (Get-Date) - $lastBoot
    Write-Host "Current uptime: $($currentUptime.Days) days, $($currentUptime.Hours) hours, $($currentUptime.Minutes) minutes"
    Write-Host "Last boot: $lastBoot"
    Write-Host ""
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Sort events by time
$sortedEvents = $events | Sort-Object TimeCreated

Write-Host "Found $($sortedEvents.Count) boot/shutdown events in the last $days days"
Write-Host ""

# Calculate total uptime
$totalUptime = [TimeSpan]::Zero
$lastBootTime = $null
$sessionCount = 0

foreach ($event in $sortedEvents) {
    $eventTime = $event.TimeCreated
    
    if ($event.EventID -eq 6005 -or $event.EventID -eq 6009) {
        # System boot
        if ($lastBootTime) {
            # Calculate uptime for previous session
            $sessionUptime = $eventTime - $lastBootTime
            $totalUptime = $totalUptime.Add($sessionUptime)
            $sessionCount++
        }
        $lastBootTime = $eventTime
    }
    elseif ($event.EventID -eq 6006 -or $event.EventID -eq 6008) {
        # System shutdown
        if ($lastBootTime) {
            $sessionUptime = $eventTime - $lastBootTime
            $totalUptime = $totalUptime.Add($sessionUptime)
            $sessionCount++
            $lastBootTime = $null
        }
    }
}

# If system is still running from last boot
if ($lastBootTime) {
    $currentUptime = $endDate - $lastBootTime
    $totalUptime = $totalUptime.Add($currentUptime)
    $sessionCount++
}

Write-Host "=========================================="
Write-Host "RESULTS"
Write-Host "=========================================="
Write-Host "Total Sessions: $sessionCount"
Write-Host ""
Write-Host "Total Uptime:"
Write-Host "  Days: $($totalUptime.Days)"
Write-Host "  Hours: $($totalUptime.Hours)"
Write-Host "  Minutes: $($totalUptime.Minutes)"
Write-Host "  Total Hours: $([math]::Round($totalUptime.TotalHours, 2))"
Write-Host "  Total Days: $([math]::Round($totalUptime.TotalDays, 2))"
Write-Host ""
Write-Host "Uptime Percentage: $([math]::Round(($totalUptime.TotalDays / $days) * 100, 2))%"
Write-Host "=========================================="
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

