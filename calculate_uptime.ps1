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

# Query events using PowerShell Get-WinEvent (more reliable with date filtering)
Write-Host "Querying Windows Event Log for boot/shutdown events..."
Write-Host "This may take a few moments..." -ForegroundColor Yellow
Write-Host ""

try {
    # Query all boot/shutdown events to find the actual date range
    # First, get newest events to find the latest date
    Write-Host "Scanning Event Log for available data range..." -ForegroundColor Cyan
    $newestEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ID = 6005, 6006, 6008, 6009
    } -MaxEvents 1 -ErrorAction SilentlyContinue
    
    if ($null -eq $newestEvents -or $newestEvents.Count -eq 0) {
        Write-Host "No boot/shutdown events found in Event Log." -ForegroundColor Red
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
    
    $newestEvent = $newestEvents[0].TimeCreated
    
    # Now query with Oldest parameter to find the oldest event
    # Get-WinEvent returns newest first, so we need to get a large sample and find the oldest
    Write-Host "Querying all available boot/shutdown events (this may take a moment)..." -ForegroundColor Cyan
    $allEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        ID = 6005, 6006, 6008, 6009
    } -ErrorAction SilentlyContinue
    
    if ($null -eq $allEvents -or $allEvents.Count -eq 0) {
        Write-Host "No boot/shutdown events found in Event Log." -ForegroundColor Red
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
    
    Write-Host "Found $($allEvents.Count) total boot/shutdown events in Event Log" -ForegroundColor Green
    
    # Find the oldest event by checking all events
    $oldestEvent = $null
    $parsedEvents = @()
    
    foreach ($evt in $allEvents) {
        $eventDate = $evt.TimeCreated
        if ($null -eq $oldestEvent -or $eventDate -lt $oldestEvent) {
            $oldestEvent = $eventDate
        }
        
        $parsedEvents += [PSCustomObject]@{
            EventID = $evt.Id
            TimeCreated = $eventDate
        }
    }
    
    # Update newest event from all events (in case first query missed it)
    foreach ($evt in $allEvents) {
        if ($evt.TimeCreated -gt $newestEvent) {
            $newestEvent = $evt.TimeCreated
        }
    }
    
    # Check Event Log retention policy and explain limitations
    try {
        $logInfo = Get-WinEvent -ListLog System -ErrorAction SilentlyContinue
        if ($logInfo) {
            Write-Host "Event Log Configuration:" -ForegroundColor Cyan
            Write-Host "  Maximum Size: $([math]::Round($logInfo.MaximumSizeInBytes / 1MB, 2)) MB"
            
            # Explain retention policy
            $retentionExplanation = switch ($logInfo.LogMode) {
                "Circular" { "Overwrites oldest events when log is full (default - limits retention)" }
                "AutoBackup" { "Archives log when full, then starts new log" }
                "Retain" { "Stops logging when full (requires manual clearing)" }
                default { $logInfo.LogMode }
            }
            Write-Host "  Retention Policy: $($logInfo.LogMode) - $retentionExplanation" -ForegroundColor Yellow
            
            if ($logInfo.OldestRecordTime) {
                $oldestInLog = $logInfo.OldestRecordTime
                $daysInLog = ((Get-Date) - $oldestInLog).TotalDays
                Write-Host "  Oldest Record in Log: $oldestInLog ($([math]::Round($daysInLog, 1)) days ago)" -ForegroundColor Yellow
                
                if ($oldestInLog -lt $oldestEvent) {
                    Write-Host "  NOTE: Log contains older records, but boot/shutdown events only go back to $oldestEvent" -ForegroundColor Yellow
                }
            }
            
            Write-Host ""
            Write-Host "Why data is limited:" -ForegroundColor Cyan
            Write-Host "  - Windows Event Logs use a CIRCULAR BUFFER (default)" -ForegroundColor White
            Write-Host "  - When the log reaches maximum size, OLDEST events are DELETED" -ForegroundColor White
            Write-Host "  - This is a Windows RESTRICTION, not a file size issue" -ForegroundColor White
            Write-Host "  - Typical retention: 1 year or less depending on system activity" -ForegroundColor White
            Write-Host "  - To keep more history, you'd need to:" -ForegroundColor White
            Write-Host "    1. Increase log size (Event Viewer > System Log > Properties)" -ForegroundColor Gray
            Write-Host "    2. Change retention to 'Archive when full' (may impact performance)" -ForegroundColor Gray
            Write-Host "    3. Use Windows Event Forwarding to archive events externally" -ForegroundColor Gray
        }
    } catch {
        # Ignore errors getting log info
    }
    
    Write-Host ""
    
    # Check if requested time frame exceeds available data
    $availableDays = ($newestEvent - $oldestEvent).TotalDays
    if ($days -gt $availableDays) {
        Write-Host "WARNING: Requested $days days, but only $([math]::Round($availableDays, 1)) days of boot/shutdown data available." -ForegroundColor Yellow
        Write-Host "Available data range: $oldestEvent to $newestEvent" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This is a WINDOWS RESTRICTION, not a file size limitation:" -ForegroundColor Yellow
        Write-Host "  - Windows Event Logs use a circular buffer that overwrites old events" -ForegroundColor White
        Write-Host "  - When the log fills up, Windows automatically deletes the oldest events" -ForegroundColor White
        Write-Host "  - This is by design to prevent logs from consuming unlimited disk space" -ForegroundColor White
        Write-Host "  - Typical retention: 1 year or less depending on system activity" -ForegroundColor White
        Write-Host ""
        Write-Host "Analysis will be limited to available data." -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Filter events to requested date range
    $events = $parsedEvents | Where-Object { 
        $_.TimeCreated -ge $startDate -and $_.TimeCreated -le $endDate 
    }
    
} catch {
    Write-Host "Error querying Event Log: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Attempting fallback method with wevtutil..." -ForegroundColor Yellow
    Write-Host ""
    
    # Fallback to wevtutil method
    $eventsFile = "$env:TEMP\events.txt"
    if (-not (Test-Path $eventsFile)) {
        Write-Host "Generating events file from Windows Event Log..."
        Write-Host "This may take a few moments..."
        wevtutil qe System /c:10000 /rd:true /f:text /q:"*[System[(EventID=6005 or EventID=6006 or EventID=6008 or EventID=6009)]]" | Out-File -FilePath $eventsFile -Encoding UTF8
        if (-not (Test-Path $eventsFile)) {
            Write-Host "Error: Could not generate events file. Please ensure you have administrator privileges." -ForegroundColor Red
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
    $oldestEvent = $null
    $newestEvent = $null
    
    foreach ($block in $eventBlocks) {
        if ($block -match 'Event ID: (\d+)') {
            $eventId = [int]$matches[1]
            if ($block -match 'Date: ([0-9TZ:.-]+)') {
                $dateStr = $matches[1]
                if ($eventId -in @(6005, 6006, 6008, 6009)) {
                    try {
                        $eventDate = [DateTime]::Parse($dateStr)
                        if ($null -eq $oldestEvent -or $eventDate -lt $oldestEvent) {
                            $oldestEvent = $eventDate
                        }
                        if ($null -eq $newestEvent -or $eventDate -gt $newestEvent) {
                            $newestEvent = $eventDate
                        }
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
    
    # Check if requested time frame exceeds available data (fallback method)
    if ($null -ne $oldestEvent -and $null -ne $newestEvent) {
        $availableDays = ($newestEvent - $oldestEvent).TotalDays
        if ($days -gt $availableDays) {
            Write-Host "WARNING: Requested $days days, but only $([math]::Round($availableDays, 1)) days of data available in Event Log." -ForegroundColor Yellow
            Write-Host "Available data range: $oldestEvent to $newestEvent" -ForegroundColor Yellow
            Write-Host "Analysis will be limited to available data." -ForegroundColor Yellow
            Write-Host ""
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

# Calculate actual date range of found events
$actualStartDate = $null
$actualEndDate = $null
if ($sortedEvents.Count -gt 0) {
    $actualStartDate = ($sortedEvents | Measure-Object -Property TimeCreated -Minimum).Minimum
    $actualEndDate = ($sortedEvents | Measure-Object -Property TimeCreated -Maximum).Maximum
    $actualDays = ($actualEndDate - $actualStartDate).TotalDays
}

Write-Host "Found $($sortedEvents.Count) boot/shutdown events"
if ($null -ne $actualStartDate -and $null -ne $actualEndDate) {
    Write-Host "Event date range: $actualStartDate to $actualEndDate"
    if ($actualDays -lt $days) {
        Write-Host "Note: Only $([math]::Round($actualDays, 1)) days of data available (requested $days days)" -ForegroundColor Yellow
    }
}
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
# Calculate percentage based on actual available days
$daysForPercentage = $days
if ($null -ne $actualStartDate -and $null -ne $actualEndDate) {
    $actualDays = ($actualEndDate - $actualStartDate).TotalDays
    if ($actualDays -lt $days) {
        $daysForPercentage = $actualDays
        Write-Host "Uptime Percentage (based on $([math]::Round($actualDays, 1)) days of available data): $([math]::Round(($totalUptime.TotalDays / $daysForPercentage) * 100, 2))%" -ForegroundColor Yellow
    } else {
        Write-Host "Uptime Percentage: $([math]::Round(($totalUptime.TotalDays / $days) * 100, 2))%"
    }
} else {
    Write-Host "Uptime Percentage: $([math]::Round(($totalUptime.TotalDays / $days) * 100, 2))%"
}
Write-Host "=========================================="
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

