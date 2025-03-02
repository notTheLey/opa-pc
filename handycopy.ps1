param(
    [string]$zielOrdner = "$env:USERPROFILE\Pictures\Handy",
    [string]$pathsFile = "$env:USERPROFILE\Pictures\Handy/paths.txt"
)

if (Test-Path $pathsFile) {
    $quellOrdner = Get-Content -Path $pathsFile
} else {
    Write-Host "Die Datei 'paths.txt' wurde nicht gefunden!"
    exit
}

if (!(Test-Path $zielOrdner)) {
    New-Item -ItemType Directory -Path $zielOrdner | Out-Null
}

$bildEndungen = @("*.png", "*.jpg", "*.jpeg", "*.jpng")
$alleBilder = @()

foreach ($ordner in $quellOrdner) {
    if (Test-Path $ordner) {
        foreach ($ext in $bildEndungen) {
            $alleBilder += Get-ChildItem -Path $ordner -Filter $ext -File -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "Ordner nicht gefunden: $ordner"
    }
}

$total = $alleBilder.Count

if ($total -eq 0) {
    Write-Host "Keine Bilder gefunden. Uebertragung abgebrochen."
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
    Write-Host -NoNewline " Kopiert Handybild in Zielordner " -BackgroundColor White -ForegroundColor Black
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
    Write-Host "Bild: $counter/$total $progress% Name: $($bild.Name.PadRight(15))" -ForegroundColor DarkGray -BackgroundColor Black
}

$counter = 0
Clear-ScreenAndPrepare

foreach ($bild in $alleBilder) {
    $counter++
    $prozent = [math]::Round(($counter / $total) * 100)
    Show-ProgressBar -progress $prozent
    [Console]::SetCursorPosition(0, [Console]::CursorTop - 2)
    Copy-Item -Path $bild.FullName -Destination $zielOrdner -Force
    Start-Sleep -Seconds 0.5
}

Start-Sleep -Seconds 3
exit
