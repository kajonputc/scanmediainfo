# =====================================================
# Media Info Scanner
# Version: 1.2.2 (Performance Optimized + Progress Bar)
# Strategy: Generic List + Fast-Key + Write-Progress
# =====================================================

# -------------------------------
# CONFIG
# -------------------------------
$LibraryPath = "D:\Movies"
$OutputCsv   = "media_info.csv"
$VideoExt    = "\.(mkv|mp4|avi|mov|webm)$"
$ScanId      = (Get-Date).ToString("yyyyMMdd_HHmmss")

# -------------------------------
# Initialize Fast Data Structures
# -------------------------------
$FinalList = [System.Collections.Generic.List[PSCustomObject]]::new()
$KnownFastKeys = @{} 
$SeenFastKeys = @{}  

# -------------------------------
# Load existing CSV
# -------------------------------
if (Test-Path $OutputCsv) {
    Write-Host ">>> Loading existing data from CSV..." -ForegroundColor Yellow
    $ExistingData = Import-Csv $OutputCsv
    foreach ($row in $ExistingData) {
        $FinalList.Add($row)
        if ($row.fast_key) {
            $KnownFastKeys[$row.fast_key] = $row
        }
    }
    Write-Host ">>> Loaded $($FinalList.Count) records." -ForegroundColor Green
} else {
    Write-Host ">>> Creating new CSV file..." -ForegroundColor Cyan
    "file_path,fast_key,filename,file_extension,file_size_byte,last_write_time_utc,duration_sec,resolution,fps,video_encoder,video_bitrate_kbps,bit_depth,audio_codec,audio_channels,audio_bitrate_kbps,audio_language,has_subtitle,subtitle_formats,status,last_seen_scan" |
        Out-File -Encoding utf8 $OutputCsv
}

# -------------------------------
# Scan Library
# -------------------------------
Write-Host ">>> Scanning directory: $LibraryPath" -ForegroundColor Cyan
$Files = Get-ChildItem $LibraryPath -Recurse -File | Where-Object { $_.FullName -match $VideoExt }
$TotalFiles = $Files.Count
$Counter = 0
$NewFilesCount = 0

foreach ($file in $Files) {
    $Counter++
    $FilePath      = $file.FullName
    $LastWriteUtc  = $file.LastWriteTimeUtc.Ticks
    $FastKey       = "$FilePath|$($file.Length)|$LastWriteUtc"
    $SeenFastKeys[$FastKey] = $true

    # --- PROGRESS BAR ---
    $PercentComplete = [math]::Floor(($Counter / $TotalFiles) * 100)
    Write-Progress -Activity "Media Scanner (v1.2.2)" `
                   -Status "Processing: $Counter of $TotalFiles ($($file.Name))" `
                   -PercentComplete $PercentComplete `
                   -CurrentOperation "$PercentComplete% Complete"

    # 1. เช็คว่าไฟล์เดิมยังอยู่และไม่เปลี่ยน (Skip)
    if ($KnownFastKeys.ContainsKey($FastKey)) {
        $existingRow = $KnownFastKeys[$FastKey]
        $existingRow.status = "active"
        $existingRow.last_seen_scan = $ScanId
        continue
    }

    # 2. ถ้าเป็นไฟล์ใหม่/เปลี่ยน (Process)
    $NewFilesCount++
    
    $Probe = ffprobe -v error `
        -select_streams v:0,a:0,s `
        -show_entries format=duration:stream=index,codec_type,codec_name,width,height,bit_rate,r_frame_rate,bits_per_raw_sample,channels:stream_tags=language `
        -of json "$FilePath" | ConvertFrom-Json

    if (-not $Probe.streams) { continue }

    $v = $Probe.streams | Where-Object { $_.codec_type -eq "video" } | Select-Object -First 1
    if (-not $v) { continue }

    $DurationSec = if ($Probe.format.duration) { [math]::Round([double]$Probe.format.duration) } else { 0 }
    $FPS = if ($v.r_frame_rate -match "(\d+)/(\d+)") { 
        $num,$den = $v.r_frame_rate -split '/'; if ($den -ne "0") { [math]::Round($num/$den, 2) } 
    }

    $a = $Probe.streams | Where-Object { $_.codec_type -eq "audio" } | Select-Object -First 1
    $Subs = $Probe.streams | Where-Object { $_.codec_type -eq "subtitle" }

    $newItem = [pscustomobject]@{
        file_path           = $FilePath
        fast_key            = $FastKey
        filename            = $file.BaseName
        file_extension      = $file.Extension.TrimStart(".").ToLower()
        file_size_byte      = $file.Length
        last_write_time_utc = $LastWriteUtc
        duration_sec        = $DurationSec
        resolution          = "$($v.width)x$($v.height)"
        fps                 = $FPS
        video_encoder       = $v.codec_name
        video_bitrate_kbps  = if ($v.bit_rate) { [math]::Round($v.bit_rate / 1000) } else { "" }
        bit_depth           = if ($v.bits_per_raw_sample) { $v.bits_per_raw_sample } else { "8" }
        audio_codec         = if ($a) { $a.codec_name } else { "none" }
        audio_channels      = if ($a) { $a.channels } else { "" }
        audio_bitrate_kbps  = if ($a -and $a.bit_rate) { [math]::Round($a.bit_rate / 1000) } else { "" }
        audio_language      = if ($a -and $a.tags.language) { $a.tags.language } else { "und" }
        has_subtitle        = if ($Subs) { "yes" } else { "no" }
        subtitle_formats    = if ($Subs) { ($Subs.codec_name | Sort-Object -Unique) -join ";" } else { "none" }
        status              = "active"
        last_seen_scan      = $ScanId
    }
    $FinalList.Add($newItem)
}

# ปิด Progress Bar เมื่อทำงานในลูปเสร็จ
Write-Progress -Activity "Media Scanner" -Completed

# -------------------------------
# Mark Missing Files
# -------------------------------
Write-Host ">>> Verifying missing files..." -ForegroundColor Yellow
foreach ($row in $FinalList) {
    if (-not $SeenFastKeys.ContainsKey($row.fast_key)) {
        $row.status = "missing"
    }
}

# -------------------------------
# Write CSV
# -------------------------------
Write-Host ">>> Saving results to $OutputCsv..." -ForegroundColor Cyan
$FinalList | Export-Csv $OutputCsv -NoTypeInformation -Encoding utf8

Write-Host "`nScan Finished!" -ForegroundColor Green
Write-Host " - Total files found: $TotalFiles"
Write-Host " - New/Updated files: $NewFilesCount"
Write-Host " - Result saved to  : $OutputCsv"
