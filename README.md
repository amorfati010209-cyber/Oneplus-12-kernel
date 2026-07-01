# NetHunter Custom Kernel — OnePlus 12 (Android 16)

Custom kernel for OnePlus 12 (SM8650 / waffle) with full **Kali NetHunter** support on Android 16.

---

## Возможности / Features

| Feature | Status |
|---|---|
| HID gadget (BadUSB / клавиатура-мышь) | ✅ |
| WiFi monitor mode + packet injection | ✅ |
| Внешние USB WiFi адаптеры (RTL88xx, MT76xx, ATH9K) | ✅ |
| Bluetooth HID / RFCOMM / BNEP | ✅ |
| Full iptables / netfilter / NAT | ✅ |
| USB OTG host mode | ✅ |
| KernelSU (root) | ✅ |
| Namespace / cgroup (для chroot) | ✅ |
| Network namespaces (TUN/TAP/VETH) | ✅ |
| Crypto API (aircrack, hashcat) | ✅ |

---

## Устройство / Device

| | |
|---|---|
| **Устройство** | OnePlus 12 |
| **Кодовое имя** | waffle / OPD2403 |
| **SoC** | Snapdragon 8 Gen 3 (SM8650) |
| **Android** | 16 |
| **Ядро** | GKI 6.1.x |

---

## Быстрый старт / Quick Start

### 1. Настройка окружения
```bash
git clone https://github.com/amorfati010209-cyber/oneplus-12-kernel
cd oneplus-12-kernel
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 2. Сборка ядра
```bash
./scripts/build.sh
# или без KernelSU:
./scripts/build.sh --no-ksu
# чистая сборка:
./scripts/build.sh --clean
```

### 3. Прошивка

**Через TWRP / OrangeFox (рекомендуется):**
```bash
# Загрузите телефон в recovery
adb reboot recovery
./scripts/flash.sh --zip
```

**Напрямую через fastboot:**
```bash
adb reboot bootloader
./scripts/flash.sh --fastboot
```

---

## Требования для прошивки

1. **OEM unlock** включен в настройках разработчика
2. **TWRP** или **OrangeFox** recovery установлен
3. Установлен **KernelSU Manager** из [официального репозитория](https://github.com/tiann/KernelSU)
4. После прошивки установите **NetHunter приложение** из [Kali NetHunter releases](https://www.kali.org/get-kali/#kali-nethunter)

---

## Установка NetHunter после прошивки ядра

1. Прошейте этот ZIP через TWRP
2. Перезагрузитесь в Android
3. Установите **KernelSU Manager** APK
4. Установите **NetHunter Store** APK
5. Через Store установите:
   - **NetHunter App**
   - **NetHunter Terminal**
   - **NetHunter KeX** (Kali desktop на телефоне)

---

## Структура репозитория

```
oneplus-12-kernel/
├── .github/workflows/
│   └── build-kernel.yml       # GitHub Actions CI/CD
├── nethunter-config/
│   ├── nethunter.config        # Основные флаги ядра для NetHunter
│   └── nethunter-wifi.config   # Конфигурация WiFi адаптеров
├── patches/
│   ├── 0001-nethunter-hid-gadget.patch
│   ├── 0002-mac80211-enable-monitor-mode.patch
│   └── 0003-add-kernelsu.patch
├── scripts/
│   ├── setup.sh               # Установка зависимостей и клонирование источников
│   ├── build.sh               # Основной скрипт сборки
│   └── flash.sh               # Прошивка на устройство
└── anykernel3/
    └── anykernel.sh           # Конфиг flashable ZIP
```

---

## GitHub Actions

Каждый push автоматически собирает ядро. Артефакты (ZIP + Image.lz4) доступны во вкладке **Actions**.

---

## Поддерживаемые USB WiFi адаптеры для инъекции

- **Alfa AWUS036ACH** — RTL8812AU (лучший выбор)
- **Alfa AWUS036ACS** — RTL8811AU
- **TP-Link TL-WN722N v1** — AR9271
- **Panda PAU09** — MT7612U
- **Alfa AWUS036NHA** — AR9271

---

## Лицензия

GPL-2.0 (наследуется от Linux kernel)
