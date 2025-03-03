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

# Process each destination with its file types
$alleDateien = @()
$zielInfos = @{}

foreach ($ziel in $config.ziele.PSObject.Properties) {
    $zielPfad = $ziel.Name -replace '\$env:USERPROFILE', $env:USERPROFILE
    
    # Create destination directory if it doesn't exist
    if (!(Test-Path $zielPfad)) {
        New-Item -ItemType Directory -Path $zielPfad -Force | Out-Null
    }
    
    # Get list of file extensions for this destination
    $dateitypen = $ziel.Value
    
    # Store information for later use
    $zielInfos[$zielPfad] = $dateitypen
}

# Collect all files from source directories
foreach ($quelle in $config.quellen) {
    if (Test-Path $quelle) {
        foreach ($zielPfad in $zielInfos.Keys) {
            foreach ($typ in $zielInfos[$zielPfad]) {
                $dateien = Get-ChildItem -Path $quelle -Filter $typ -File -ErrorAction SilentlyContinue
                foreach ($datei in $dateien) {
                    $alleDateien += [PSCustomObject]@{
                        FullName = $datei.FullName
                        Name = $datei.Name
                        ZielPfad = $zielPfad
                    }
                }
            }
        }
    } else {
        Write-Host "Quellordner nicht gefunden: $quelle"
    }
}

$total = $alleDateien.Count
if ($total -eq 0) {
    Write-Host "Keine Dateien gefunden. Übertragung abgebrochen."
    Start-Sleep -Seconds 3
    exit
}

function Clear-ScreenAndPrepare {
    $screenHeight = [System.Console]::WindowHeight
    $emptyLines = $screenHeight - 3
    $width = $Host.UI.RawUI.WindowSize.Width
    if ($width -lt 40) { $width = 40 }
    $back = "_" * ($width - 40)
    Write-Host -NoNewline "___|" -BackgroundColor Black -ForegroundColor White
    Write-Host -NoNewline " Kopiert Dateien in Zielordner " -BackgroundColor White -ForegroundColor Black
    Write-Host -NoNewline "|$back" -BackgroundColor Black -ForegroundColor White
    [Console]::SetCursorPosition(0, 0)
    for ($i = 0; $i -lt $emptyLines; $i++) {
        Write-Host ""
    }
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

$counter = 0
Clear-ScreenAndPrepare

foreach ($datei in $alleDateien) {
    $counter++
    $prozent = [math]::Round(($counter / $total) * 100)
    Show-ProgressBar -progress $prozent
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 2)
    Copy-Item -Path $datei.FullName -Destination $datei.ZielPfad -Force
    Start-Sleep -Milliseconds 500
}

Write-Host "`n`nÜbertragung abgeschlossen: $counter Dateien kopiert."
Start-Sleep -Seconds 3
exit
