# XYZ Player 🚀

> **High-Performance Open-Source Video Player & Real-Time AI Upscaler with Seamless Browser Integration.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Vulkan](https://img.shields.io/badge/Graphics-Vulkan%20%7C%20gpu--next-red.svg)](https://vulkan.org)
[![mpv](https://img.shields.io/badge/Engine-mpv%20v0.41+-purple.svg)](https://mpv.io)
[![Extension](https://img.shields.io/badge/Browser-Chrome%20MV3-green.svg)](extension/)

**XYZ Player** is a complete, lightweight, hardware-accelerated media solution designed for watching web streams and local video files with real-time AI upscaling, smooth frame synchronization, and a custom modern OSD interface.

---

## ✨ Key Features

* **🎨 Custom Modern Frameless UI (`xyz_ui.lua`):**
  * Borderless, sleek media interface drawn in native vector ASS at high refresh rates (up to 144Hz+).
  * **Interactive Popup Menu:** Single-click category picker for Anime and Real-World/Cinema shaders.
  * **Top-Right Real-Time HUD:** Live Vulkan/GPU pass latency (`ms`), input/output resolution, dropped frames, audio codec info, and display FPS.
  * **⏩ 2.0x Speed on Hold:** Long-press `SPACE` to instantly speed up to 2.0x (YouTube style); release to resume normal speed.
* **🧠 Real-Time AI & Shader Upscaling:**
  * **Anime & Animation:** Multi-tier Convolutional Neural Network (CNN) restoration and upscaling via **Anime4K** (Balanced M, High-Quality L, Ultra VL, and Soft Denoise).
  * **Films, TV Series & YouTube:** **AMD FidelityFX Super Resolution 1.0 (EASU + RCAS)**, **SSimSuperRes** perceptual cinema texture recovery, and Bilateral Denoise.
* **⚡ Display-Resample & Temporal Oversampling:**
  * Eliminates micro-stutter (*judder*) by matching video presentation to your monitor's exact refresh rate (`display-resample` + `tscale=oversample`) without soap-opera distortion.
* **🌐 One-Click Browser Integration:**
  * Lightweight Chrome Extension (Manifest V3) automatically detects video and `.m3u8` streams, captures the required Referer/Origin headers to prevent HTTP 403 blocks, and launches the desktop player via a custom protocol (`xyz://`).

---

## 📸 Interface Preview

* **Top Bar:** Frameless window drag region, video title, and window management controls (Minimize, Fullscreen, Close).
* **Bottom Bar:** Cyan progress bar with time-hover tooltip, Play/Pause, ±10s seek, current/total time, volume scroll, and 3 custom toggle buttons:
  * 🪄 **Shader Preset Selector:** Opens categorized Anime & Real-World upscaler menu.
  * ⚡ **Motion Sync Toggle:** Toggles smooth frame synchronization.
  * 📊 **HUD Stats Toggle:** Toggles real-time Vulkan render metrics card.

---

## ⌨️ Shortcuts Reference

| Shortcut | Action |
|---|---|
| **`SPACE` (Tap)** | Play / Pause |
| **`SPACE` (Hold)** | **2.0x Playback Speed** (reverts on release) |
| **`i`** | Toggle Top-Right Vulkan & Upscaler HUD Card |
| **`CTRL + 1`** | Anime4K: Balanced (Restore + Upscale M) |
| **`CTRL + 2`** | Anime4K: High Quality (Restore + Upscale L) |
| **`CTRL + 3`** | Anime4K: Soft / Denoise Mode |
| **`CTRL + 4`** | AMD FSR 1.0 + RCAS (Movies, Series & YouTube) |
| **`CTRL + 5`** | SSimSuperRes (Cinema & Natural Texture) |
| **`CTRL + 0`** | Disable all shaders (Original source) |
| **`Mouse Wheel`** | Volume Up / Down (±5%) |
| **`Double Click`** | Toggle Fullscreen |

---

## 🚀 Quick Setup Guide

### 1. Prerequisites & Binaries
Because `mpv` and `yt-dlp` executables exceed GitHub's single-file limits, install or update them directly:
1. Run `mpv/updater.bat` to automatically fetch the latest `mpv.exe` and `yt-dlp.exe` builds.
   * *Alternatively*, place your own `mpv.exe` and `yt-dlp.exe` into the `mpv/` directory.

### 2. Register Custom URL Protocol
1. Double-click `register_protocol.reg` to register the `xyz://` protocol handler in Windows.
   * If your project is located outside `D:\xyz-player`, update the path in `register_protocol.reg` accordingly.

### 3. Install Browser Extension
1. Open Google Chrome and navigate to `chrome://extensions`.
2. Enable **Developer mode** in the top right corner.
3. Click **Load unpacked** and select the `extension/` folder from this repository.
4. Browse to any supported video streaming page (or YouTube) and click the **XYZ Player** extension icon to launch playback!

---

## 📁 Repository Structure

```text
xyz-player/
├── extension/                 # Chrome Manifest V3 extension
│   ├── background.js          # Stream interception & protocol bridge
│   ├── manifest.json
│   └── icon.png
├── mpv/
│   ├── portable_config/       # Self-contained mpv configuration
│   │   ├── mpv.conf           # Vulkan, gpu-next, and display settings
│   │   ├── input.conf         # Keybindings and shader shortcuts
│   │   └── scripts/           # Active Lua scripts (xyz_ui.lua, strip_protocol.lua)
│   ├── mpv-register.bat       # Windows file association helper
│   ├── mpv-unregister.bat
│   └── updater.bat            # Auto-updater for mpv and yt-dlp binaries
├── scripts/                   # Standalone Lua scripts
│   ├── xyz_ui.lua             # Custom OSD & HUD engine
│   └── strip_protocol.lua     # URL scheme parser & header inject
├── shaders/                   # GLSL real-time shaders
│   ├── Anime4K_*.glsl         # Anime4K v4.0 CNN neural network shaders
│   ├── FSR_EASU_RCAS.glsl     # AMD FidelityFX Super Resolution port
│   └── SSimSuperRes_Natural.glsl # Structural Similarity cinema enhancer
├── register_protocol.reg      # Windows Registry protocol entry
├── LICENSE                    # MIT License
└── README.md
```

---

## 📜 Credits & Acknowledgements

* **[mpv player](https://mpv.io/)** — Powerful, lightweight media player engine.
* **[libplacebo](https://github.com/haasn/libplacebo)** — Next-generation graphics rendering and Vulkan primitives.
* **[Anime4K](https://github.com/bloc97/Anime4K)** by bloc97 — High-performance real-time anime upscaling algorithms.
* **[AMD FidelityFX](https://gpuopen.com/fidelityfx-superresolution/)** — Contrast-Adaptive Sharpening and spatial upsampling.
* **[yt-dlp](https://github.com/yt-dlp/yt-dlp)** — Stream extraction backend.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
