# 🎬 Media Info Scanner v1.2.2

> **Filename:** `scan_media_info_v1.2.2.ps1`  
> **Platform:** Windows / PowerShell 5.1+  
> **Purpose:** Scan media library → export structured CSV → track file state over time

---

## 📌 Overview

`scan_media_info_v1.2.2.ps1` เป็นสคริปต์สำหรับสแกน media library (เช่น Movies / Series)
โดยออกแบบมาเพื่อใช้งานระยะยาวกับ **Jellyfin / Plex workflow**

จุดเน้นของเวอร์ชันนี้คือ:
- ความเร็ว (Fast-Key)
- ความเสถียร (ไม่ลบข้อมูลเก่า)
- UX ที่ดีขึ้น (Progress Bar)

เหมาะสำหรับ:
- NAS / HDD
- library ขนาดใหญ่ (หลายพัน–หลายหมื่นไฟล์)
- การวิเคราะห์ก่อน re-encode

---

## 🚀 Key Features (v1.2.2)

### ✅ Fast-Key Strategy
ใช้ข้อมูลจาก filesystem เพื่อตรวจการเปลี่ยนแปลงไฟล์
โดยไม่เรียก `ffprobe` ซ้ำโดยไม่จำเป็น

```text
FAST_KEY = file_path + file_size_byte + last_write_time_utc
```

ผลลัพธ์:
- เรียก `ffprobe` เฉพาะไฟล์ใหม่ / ไฟล์ที่เปลี่ยนจริง
- ลดเวลา scan อย่างมาก

---

### ✅ State Tracking (File Lifecycle)

| State | Meaning |
|---|---|
| active | พบไฟล์ในรอบ scan ล่าสุด |
| missing | เคยพบไฟล์ แต่รอบนี้ไม่พบ |

> ❗ ไม่มีการลบ row ใด ๆ จาก CSV

รองรับกรณี:
- NAS หลุดชั่วคราว
- external drive offline
- ต้องการเก็บ history

---

### ✅ Progress Bar (UX Improvement)

เพิ่ม `Write-Progress` เพื่อ:
- แสดงความคืบหน้าแบบ real-time
- ลดความสับสนเมื่อ scan ใช้เวลานาน
- เหมาะกับ run แบบ unattended

---

## 📂 Supported Media

- **Video containers:** mkv, mp4, avi, mov, webm
- **Audio:** วิเคราะห์ track แรก (primary audio)
- **Subtitle:** ตรวจเฉพาะ subtitle ที่ฝังใน container

> External subtitle (.srt) ไม่ถูก scan ในสคริปต์นี้

---

## 📄 CSV Schema (v1.2.2)

```csv
file_path
fast_key
filename
file_extension
file_size_byte
last_write_time_utc
duration_sec
resolution
fps
video_encoder
video_bitrate_kbps
bit_depth
audio_codec
audio_channels
audio_bitrate_kbps
audio_language
has_subtitle
subtitle_formats
status
last_seen_scan
```

### Field Description

| Field | Description |
|---|---|
| file_path | path เต็มของไฟล์ (unique identity) |
| fast_key | key สำหรับตรวจการเปลี่ยนแปลงไฟล์ |
| filename | ชื่อไฟล์ไม่รวม extension |
| file_extension | นามสกุลไฟล์ (lowercase) |
| file_size_byte | ขนาดไฟล์ (byte) |
| last_write_time_utc | เวลาที่ไฟล์ถูกแก้ไขล่าสุด (UTC ticks) |
| duration_sec | ความยาววิดีโอ (วินาที) |
| resolution | ความละเอียด เช่น 1920x1080 |
| fps | frame rate |
| video_encoder | codec วิดีโอ (h264 / hevc / av1) |
| video_bitrate_kbps | bitrate วิดีโอ |
| bit_depth | bit depth (8 / 10) |
| audio_codec | codec เสียง (aac / ac3 / dts / truehd) |
| audio_channels | จำนวน channel |
| audio_bitrate_kbps | bitrate เสียง |
| audio_language | ภาษาเสียง (en / th / und) |
| has_subtitle | yes / no |
| subtitle_formats | srt / ass / pgs / mov_text |
| status | active / missing |
| last_seen_scan | scan id ล่าสุดที่พบไฟล์ |

---

## 🔄 Scan Workflow

```text
Load existing CSV (if exists)
↓
Scan filesystem
↓
Generate Fast-Key
↓
Known key → update state only
New key → ffprobe → append row
↓
Mark missing files
↓
Rewrite CSV safely
```

---

## 🧪 Typical Use Cases

### 🎯 Jellyfin Direct Play Analysis
- video_encoder = h264
- audio_codec = dts / truehd
- subtitle_formats = pgs

### 🎯 Re-encode Candidate Detection
- bitrate สูงผิดปกติ
- 1080p h264 → hevc
- audio_channels > 2

### 🎯 Missing File Audit
- filter: `status = missing`

---

## 🏷 Versioning Policy

```text
vMAJOR.MINOR.PATCH
```

| Level | Meaning |
|---|---|
| MAJOR | เปลี่ยน schema / key (breaking) |
| MINOR | เพิ่ม field / feature |
| PATCH | performance / bugfix |

### Version History

- v1.2.0 – Fast-Key + State Tracking
- v1.2.1 – minor bugfix
- v1.2.2 – performance optimization + progress bar

---

## 📎 Requirements

- Windows
- PowerShell 5.1+
- ffmpeg / ffprobe available in PATH

---

## ✅ Summary

`scan_media_info_v1.2.2.ps1` เป็นสคริปต์ระดับ production
สำหรับจัดการ media library อย่างเป็นระบบ


