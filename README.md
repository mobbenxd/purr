<div align="center">

# Purr 🐱

**แมวน้อยบน menu bar ที่ช่วยดูแลเครื่อง Mac ของคุณ**

ล้างแคช, optimize ระบบ, ดู CPU / แรม / ดิสก์ — ทั้งหมดแค่คลิกเดียว

<img src="docs/moods.png" alt="อารมณ์ต่างๆ ของแมว Purr" width="720" />

</div>

---

Purr คือหน้าตาแบบกดง่ายๆ (GUI) ที่ครอบ [Mole](https://github.com/tw93/mole) — เครื่องมือ command line ทำความสะอาด Mac ชื่อดัง
แทนที่จะต้องจำคำสั่ง `mo clean`, `mo optimize` ฯลฯ ก็แค่กดที่แมวบนแถบเมนูด้านบนของจอ

> Purr เป็นโปรเจกต์ส่วนตัว ไม่ได้เกี่ยวข้องหรือได้รับการรับรองจากทีม Mole — Purr แค่ไปเรียกใช้ `mo` ที่คุณติดตั้งไว้ในเครื่องเท่านั้น

## ✨ ทำอะไรได้บ้าง

| | สิ่งที่เห็น / ปุ่ม | คำสั่งที่รันจริง | หมายเหตุ |
|---|---|---|---|
| 🐱 | หน้าแมว + คะแนนสุขภาพ | `mo status` | แมวในแผงและบนแถบเมนูเปลี่ยนอารมณ์ตามสภาพเครื่อง คลิกเพื่อลูบหัวได้ |
| 📊 | CPU / แรม / ดิสก์ว่าง | `mo status --watch` | กดที่ตัวเลขเพื่อดู swap, แบตเตอรี่, อุณหภูมิ และโปรแกรมที่กิน CPU มากสุด |
| 👃 | **ดมก่อน** | `mo clean --dry-run` | ดูอย่างเดียว ไม่ลบอะไร |
| 🧹 | **เลียขน** | `mo clean` | ลบแคช/ล็อก/ถังขยะ **ถาวร** (ถามยืนยันก่อน) |
| 🧘 | **ยืดเส้น** | `mo optimize` | รีเฟรช DNS, QuickLook, ไอคอน ฯลฯ (ถามยืนยันก่อน) |
| 📦 | **คุ้ยโปรเจกต์** | `mo purge --dry-run` | หา `node_modules`, `build`, `dist` ที่ลบได้ แล้วกด **ลบที่เจอทั้งหมด** (`mo purge --yes`) ต่อได้เลย |
| 🕘 | ประวัติ | `mo history --json` | ดูว่าแต่ละครั้งได้พื้นที่คืนเท่าไร |
| 🗑️ 🔎 💿 | ถอนแอป / สำรวจดิสก์ / ไฟล์ติดตั้ง | `mo uninstall` / `analyze` / `installer` | เปิดใน Terminal |
| 🛡️ | ยกเว้น | `mo clean --whitelist` | เลือกแคชที่ไม่อยากให้ลบ (เปิดใน Terminal) |
| 🔐 | ล้างทั้งระบบ | `mo clean` | รวมแคชระดับระบบ ต้องใส่รหัส admin (เปิดใน Terminal) |

งานในกลุ่ม "งานแมว" รันในแอปและแสดง log สดๆ (กด **หยุด** ได้ทุกเมื่อ) ส่วนงานที่ต้องเลือกรายการด้วยคีย์บอร์ดจะเปิดหน้าต่าง Terminal ให้

**แมวดูแลเครื่องให้เองด้วย** (ปิด/เปิดได้ใน ⚙️ ตั้งค่า)

- 🔔 แจ้งเตือนเมื่อดิสก์ใกล้เต็ม, แรมตึง, มีโปรแกรมกิน CPU นานผิดปกติ หรือเมื่องานเสร็จตอนปิดแผงอยู่
- 👃 แอบดมทุกสัปดาห์ แล้วบอกเมื่อมีของให้ลบเยอะ
- 🎁 บอกเมื่อ Purr หรือ Mole มีเวอร์ชันใหม่
- 🌏 ภาษาไทย / English, เปิดอัตโนมัติเมื่อเข้าเครื่อง, เสียงครางเมื่องานเสร็จ

## 📋 สิ่งที่ต้องมี

- **macOS 14 (Sonoma) ขึ้นไป**
- **Swift 5.9+** — มากับ Xcode หรือ Command Line Tools
- **Mole** (`mo`)

## 🚀 ติดตั้ง (ประมาณ 3 นาที)

**1. ติดตั้ง Command Line Tools** (ข้ามได้ถ้ามี Xcode หรือเคยติดตั้งแล้ว)

```bash
xcode-select --install
```

เช็กว่าพร้อมแล้ว: `swift --version` ต้องขึ้นเลขเวอร์ชัน

**2. ติดตั้ง Mole**

```bash
brew install mole
```

ยังไม่มี Homebrew? ติดตั้งจาก [brew.sh](https://brew.sh) ก่อน หรือใช้สคริปต์ของ Mole:
`curl -fsSL https://raw.githubusercontent.com/tw93/mole/main/install.sh | bash`

เช็กว่าพร้อมแล้ว: `mo --version`

**3. โหลดและ build Purr**

```bash
git clone https://github.com/mobbenxd/purr.git
cd purr
./build.sh
```

ครั้งแรกใช้เวลาราว 1 นาที เสร็จแล้วจะได้ `Purr.app` ในโฟลเดอร์นี้

**4. ย้ายไป Applications แล้วเปิด**

```bash
mv Purr.app /Applications/
open /Applications/Purr.app
```

จะเห็นหน้าแมว 🐱 ที่แถบเมนูด้านบนขวาของจอ (Purr ไม่มีไอคอนใน Dock) — คลิกเลย!

**5. (ไม่บังคับ) ให้เปิดเองทุกครั้งที่เข้าเครื่อง**

คลิกแมว → ⚙️ → เปิด **เปิด Purr อัตโนมัติเมื่อเข้าเครื่อง**

## 🔄 อัปเดตเป็นเวอร์ชันใหม่

เมื่อมีเวอร์ชันใหม่ Purr จะแจ้งเตือนและขึ้นแถบ 🎁 ในแผงเอง (เช็กวันละครั้ง ปิดได้ในตั้งค่า)
เวอร์ชันที่ใช้อยู่ดูได้ที่มุมล่างซ้ายของแผง

**ถ้าดาวน์โหลดไฟล์ `.zip`** จากหน้า Releases: แตกไฟล์แล้วลาก `Purr.app` ไปทับใน Applications

**ถ้า build เอง:**

```bash
cd purr
git pull
./build.sh
pkill -x Purr; rm -rf /Applications/Purr.app && mv Purr.app /Applications/ && open /Applications/Purr.app
```

## 🧹 ถอนการติดตั้ง

ออกจากแอป (คลิกแมว → **ออก**) แล้วลบ `/Applications/Purr.app` ได้เลย
ถ้าอยากลบค่าที่ตั้งไว้ด้วย: `defaults delete local.purr.menubar`

## 🛟 ความปลอดภัย

- เริ่มจาก **👃 ดมก่อน** เสมอ เพื่อดูว่าจะลบอะไรบ้าง รายการเต็มอยู่ที่ `~/.config/mole/clean-list.txt`
- **🧹 เลียขน** ลบถาวร ไม่ผ่านถังขยะ ถ้ามีแคชที่อยากเก็บไว้ ให้ตั้งค่าด้วย `mo clean --whitelist` ใน Terminal
- เวลารันจากในแอป Mole จะล้างเฉพาะส่วนของผู้ใช้ แคชระดับระบบที่ต้องใช้รหัสผ่าน admin จะถูกข้าม (ถ้าอยากล้างด้วย ให้รัน `mo clean` ใน Terminal)
- ดูประวัติสิ่งที่ถูกลบได้จากปุ่ม 🕘 **ประวัติ** มุมล่างของแผง

## ❓ แก้ปัญหา

<details>
<summary><b>แมวขึ้นว่า "หา <code>mo</code> ไม่เจอ"</b></summary>

Purr หา `mo` ใน `/opt/homebrew/bin`, `/usr/local/bin`, `~/.local/bin` และ `/run/current-system/sw/bin`
ติดตั้ง Mole ตามขั้นตอนที่ 2 แล้วปิด-เปิด Purr ใหม่ ถ้าติดตั้งไว้ที่อื่น เช็กด้วย `which mo`
</details>

<details>
<summary><b><code>./build.sh</code> ขึ้น error <code>swift: command not found</code> หรือ <code>xcrun: error</code></b></summary>

ติดตั้ง Command Line Tools ตามขั้นตอนที่ 1 ถ้ามี Xcode อยู่แล้วแต่ยัง error ลอง
`sudo xcode-select --switch /Applications/Xcode.app`
</details>

<details>
<summary><b><code>./build.sh</code> ขึ้น <code>permission denied</code></b></summary>

```bash
chmod +x build.sh
```
</details>

<details>
<summary><b>กดปุ่มกลุ่ม "เปิดใน Terminal" แล้วไม่มีอะไรเกิดขึ้น</b></summary>

Purr สร้างไฟล์ `.command` แล้วให้ macOS เปิดด้วยแอป Terminal ถ้า macOS ถามสิทธิ์ ให้กดอนุญาต
หรือถ้าเคยตั้งให้ไฟล์ `.command` เปิดด้วยแอปอื่น ให้คลิกขวาไฟล์ `.command` ใดๆ → Get Info → Open with → Terminal
</details>

<details>
<summary><b>เปิดแอปที่ดาวน์โหลดมาแล้วขึ้นว่า "damaged" หรือ "cannot be opened"</b></summary>

ไฟล์ที่ไม่ได้ notarize กับ Apple จะถูก macOS กันไว้ ให้รัน

```bash
xattr -dr com.apple.quarantine /Applications/Purr.app
```
</details>

<details>
<summary><b>ไม่มีแจ้งเตือนเด้งขึ้นมา</b></summary>

System Settings → Notifications → Purr → เปิด Allow Notifications
(แจ้งเตือนทำงานเฉพาะตอนเปิดจาก `Purr.app` ไม่ใช่ `swift run`)
</details>

<details>
<summary><b>หาแมวบน menu bar ไม่เจอ</b></summary>

ถ้า menu bar มีไอคอนเยอะเกินไป (โดยเฉพาะ MacBook ที่มีรอยบาก) ไอคอนอาจถูกซ่อน ลองซ่อนไอคอนอื่นด้วยการกด ⌘ ค้างแล้วลากออก
</details>

## 🛠 สำหรับนักพัฒนา

```
Sources/
├── PurrCore/              # ส่วนที่ไม่มี UI และมี test ครอบ
│   ├── GroupProcess.swift   # รันคำสั่งใน process group ของตัวเอง (กดหยุดแล้วหยุดทั้งหมด)
│   ├── MoleCLI.swift        # หา `mo` และเรียกแบบไม่ต้องตอบคำถาม
│   ├── MoleStatus.swift     # อ่าน JSON จาก `mo status`
│   ├── MoleHistory.swift    # อ่าน JSON จาก `mo history`
│   ├── OutputParser.swift   # ดึงตัวเลขสรุปจาก output ของ Mole
│   ├── Health.swift         # คะแนนสุขภาพ + กฎการแจ้งเตือน
│   ├── LogBuffer.swift      # เก็บ log แบบตัด ANSI/spinner
│   ├── SemanticVersion.swift# เทียบเวอร์ชัน + อ่าน GitHub release
│   └── SystemStats.swift    # อ่าน CPU/แรม/ดิสก์เอง (ใช้ตอนไม่มี Mole)
└── Purr/                  # แอป SwiftUI
    ├── PurrApp.swift        # จุดเริ่มแอป + ต่อ service เข้าด้วยกัน
    ├── PurrModel.swift      # รายการงาน + การรัน `mo`
    ├── StatusMonitor.swift  # `mo status --watch` (เร็วตอนเปิดแผง ช้าตอนปิด)
    ├── CareService.swift    # แจ้งเตือนสุขภาพเครื่อง + ดมประจำสัปดาห์
    ├── UpdateChecker.swift  # เช็กเวอร์ชันใหม่จาก GitHub Releases
    ├── PurrPanel.swift      # หน้าหลักของแผง
    ├── PanelPages.swift     # หน้าประวัติ + ตั้งค่า
    └── CatFace.swift        # วาดหน้าแมว ไอคอนแถบเมนู และไอคอนแอป
Resources/en.lproj/        # คำแปลภาษาอังกฤษ (ภาษาไทยคือข้อความต้นฉบับในโค้ด)
```

- รันแบบ debug: `swift run` หรือ `swift run Purr --window` (เปิดแผงเป็นหน้าต่างธรรมดา, ใส่ `history` หรือ `settings` ต่อท้ายได้)
- รัน test: `./test.sh` (ถ้ามี Xcode ใช้ `swift test` ได้เลย)
- แก้ข้อความใน UI แล้วรัน `scripts/check-strings.sh` เพื่อดูว่าข้อความไหนยังไม่มีคำแปลใน `Resources/en.lproj/Localizable.strings`
- เพิ่ม/แก้ปุ่ม: แก้ `CatTasks` ใน `PurrModel.swift`
- เปลี่ยนสีขนแมว: แก้ `fur`, `furDark`, `pink` ใน `CatFace.swift`

### เวอร์ชันและการออก release

ใช้ [Semantic Versioning](https://semver.org/): เลขเวอร์ชันอยู่ในไฟล์ `VERSION` ส่วนเลข build คือจำนวน commit
สิ่งที่เปลี่ยนในแต่ละเวอร์ชันจดไว้ใน [CHANGELOG.md](CHANGELOG.md)

1. เขียนหัวข้อ `## [X.Y.Z] - วันที่` ใน `CHANGELOG.md` แล้ว merge เข้า `main`
2. รัน `scripts/release.sh X.Y.Z` สคริปต์จะรัน test, อัปเดต `VERSION`, build, ทำไฟล์ `dist/Purr-X.Y.Z.zip`, สร้าง tag `vX.Y.Z` และไฟล์ Homebrew cask `dist/purr.rb`
3. ตรวจดูแล้วรันซ้ำพร้อม `--publish` หรือรันคำสั่ง `git push` / `gh release create` ที่สคริปต์พิมพ์ให้

เมื่อ release ขึ้น GitHub แล้ว Purr ทุกเครื่องจะแจ้งเตือนภายในหนึ่งวัน

ถ้ามีบัญชี Apple Developer: ตั้ง `PURR_SIGN_IDENTITY="Developer ID Application: …"` และ `NOTARY_PROFILE` (จาก `xcrun notarytool store-credentials`) ก่อนรันสคริปต์ จะได้แอปที่เซ็นและ notarize แล้ว ผู้ใช้เปิดได้เลยโดยไม่ต้องใช้ `xattr`

## 🙏 ขอบคุณ

- [Mole](https://github.com/tw93/mole) โดย [@tw93](https://github.com/tw93) — เครื่องมือที่ทำงานจริงอยู่เบื้องหลังทุกปุ่ม
