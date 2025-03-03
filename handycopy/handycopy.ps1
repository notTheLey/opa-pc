# Import configuration from JSON file
$configPath = "$env:APPDATA\lennard\handy\config.json"

if (!(Test-Path $configPath)) {
    Write-Host "Configuration file not found at: $configPath"
    exit
}

try {
    $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error reading config file: $_"
    exit
}

# Verify config structure
if (!($config.PSObject.Properties.Name -contains "quellen") -or 
    !($config.PSObject.Properties.Name -contains "ziele")) {
    Write-Host "Configuration file missing required sections: 'quellen' and 'ziele'"
    exit
}

$errorMessages = @()
$alleDateien = @()
$zielInfos = @{}

foreach ($ziel in $config.ziele.PSObject.Properties) {
    $zielPfad = $ziel.Name -replace '\$env:USERPROFILE', $env:USERPROFILE
    
    if (!(Test-Path $zielPfad)) {
        try {
            New-Item -ItemType Directory -Path $zielPfad -Force | Out-Null
        } catch {
            $errorMessages += "Fehler beim Erstellen von Verzeichnis $zielPfad`: $_"
        }
    }
    
    $dateitypen = $ziel.Value
    
    # Store information for later use
    $zielInfos[$zielPfad] = $dateitypen
}

# Collect all files from source directories
foreach ($quelle in $config.quellen) {
    if (Test-Path $quelle) {
        foreach ($zielPfad in $zielInfos.Keys) {
            foreach ($typ in $zielInfos[$zielPfad]) {
                try {
                    $dateien = Get-ChildItem -Path $quelle -Filter $typ -File -ErrorAction Stop
                    foreach ($datei in $dateien) {
                        $alleDateien += [PSCustomObject]@{
                            FullName = $datei.FullName
                            Name = $datei.Name
                            ZielPfad = $zielPfad
                        }
                    }
                } catch {
                    $errorMessages += "Fehler beim Durchsuchen von $quelle nach $typ`: $_"
                }
            }
        }
    } else {
        $errorMessages += "Quellordner nicht gefunden: $quelle"
    }
}

$total = $alleDateien.Count
if ($total -eq 0) {
    Write-Host "Keine Dateien gefunden. Uebertragung abgebrochen."
    Start-Sleep -Seconds 3
    exit
}

function Clear-ScreenAndPrepare {
    $screenHeight = [System.Console]::WindowHeight
    $emptyLines = $screenHeight - 3
    $width = $Host.UI.RawUI.WindowSize.Width
    if ($width -lt 40) { $width = 40 }
    $back = "_" * ($width - 37)
    Write-Host -NoNewline "____|" -BackgroundColor Black -ForegroundColor White
    Write-Host -NoNewline " Kopiert Dateien in Zielordner " -BackgroundColor White -ForegroundColor Black
    Write-Host -NoNewline "|$back" -BackgroundColor Black -ForegroundColor White
    Write-Host ""
}

function Show-ErrorMessages {
    param(
        [array]$messages
    )
    
    Write-Host "Fehler und Warnungen:" -ForegroundColor DarkGray
    
    if ($messages.Count -eq 0) {
        Write-Host "Keine Fehler aufgetreten." -ForegroundColor DarkGray
    } else {
        foreach ($msg in $messages) {
            Write-Host " - $msg" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n`n"
}

function Show-ProgressBar {
    param (
        [int]$progress
    )
    $width = $Host.UI.RawUI.WindowSize.Width
    if ($width -lt 20) { $width = 20 }
    $filled = " " * (($width * $progress) / 100)
    $empty = " " * ($width - $filled.Length)
    Write-Host -NoNewline "`r" -BackgroundColor Green -ForegroundColor Black
    Write-Host -NoNewline "$filled" -BackgroundColor Green
    Write-Host -NoNewline "$empty" -BackgroundColor DarkGray
    Write-Host "Datei: $counter/$total $progress% Name: $($datei.Name.PadRight(15))" -ForegroundColor DarkGray -BackgroundColor Black
}

Clear-ScreenAndPrepare
Show-ErrorMessages -messages $errorMessages

$screenHeight = [System.Console]::WindowHeight
[Console]::SetCursorPosition(0, $screenHeight - 3)

$counter = 0
foreach ($datei in $alleDateien) {
    $counter++
    $prozent = [math]::Round(($counter / $total) * 100)
    [Console]::SetCursorPosition(0, $screenHeight - 3)
    
    Show-ProgressBar -progress $prozent
    
    try {
        Copy-Item -Path $datei.FullName -Destination $datei.ZielPfad -Force -ErrorAction Stop
    } catch {
        $errorMessages += "Fehler beim Kopieren von $($datei.Name): $_"
        [Console]::SetCursorPosition(0, 1)
        [Console]::Clear()
        Clear-ScreenAndPrepare
        Show-ErrorMessages -messages $errorMessages
    }
}

[Console]::SetCursorPosition(0, $screenHeight - 1)
Start-Sleep -Seconds 3
exit
