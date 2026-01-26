# mpv-auto-torrent-title

![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)
![Lua](https://img.shields.io/badge/Language-Lua-blue.svg)
![MPV](https://img.shields.io/badge/Player-MPV-purple.svg)

A Lua script for **MPV** that automatically retrieves and sets the correct media title for torrents (magnet links or `.torrent` files).

It resolves messy filenames (e.g., `announce&tr=dht:...`) into clean, readable titles (e.g., `Movie Name (2024)`)

## Table of Contents

*   [Features](#features)
*   [Requirements](#requirements)
*   [Installation](#installation)
*   [How It Works](#how-it-works)
*   [Torrent Metadata Server](#torrent-metadata-server)
*   [Notes](#notes)
*   [Support](#support)
*   [License](#license)

## Features

*   **Automatic Detection**: Instantly detects magnet links and localhost torrent streams.
*   **Dual Backend**: Works with [Stremio service](https://www.stremio.com/download-service) (default) or using either a local instance or the public endpoint of [torrent-metadata](https://github.com/schardev/torrent-metadata).
*   **Fast and reactive**: Reacts efficiently to requests and solves them quickly.
*   **Smart recognition**: Automatically detects which file is being played from a torrent with multiple files.
*   **Smart Trimming**: Cleans up titles by removing extensions, spacing, and tags (if configured).
*   **Caching**: Caches infohashes and corresponding tile to disk to avoid repeated work.
*   **Async Updates**: Checks for script updates on GitHub automatically.
*   **Cross-Platform**: Works on Windows, macOS, and Linux (hopefully).
*   **Highly Customizable**: You can customize the script behaviour very specifically based on your preferences and needs.

## Requirements

1.  [**MPV**](https://mpv.io/): The media player itself.
2.  [**cURL**](https://curl.se/): Required for making API requests.
    *   *Windows 10/11 & macOS*: Pre-installed.
    *   *Linux*: `sudo apt install curl` (or equivalent).
3.  **[Optional] [torrent-metadata](https://github.com/schardev/torrent-metadata)**: Only required if you do **not** use Stremio/Stremio service **or/and** want a self-hosted fallback. See [Torrent Metadata Local Server](#local).

## Installation

1. **Git**: Navigate to the script directory and run `git pull`.  
   **Manual**: Download the latest release and extract the script folder in your scripts directory.
2. Launch MPV once. The script will automatically install the default configuration file in your script-opts directory.
3. Configure the mpv-auto-torrent-title.conf file in your script-opts directory.

Usual script directory path:
*   **Windows**: `...\mpv\scripts\`
*   **Linux/macOS**: `~/.config/mpv/scripts/`

**File Structure after installation:**
```text
mpv/
├── scripts/
│   └── mpv-auto-torrent-title/
│       ├── main.lua                    # Main script
│       ├── set_torrent_title.lua       # Title logic module
│       ├── start_torrent_metadata.lua  # Local server starter module
│       ├── loghelper.lua               # Logging helper
│       ├── mpv-auto-torrent-title.conf # Default config file (keep as it is)
│       ├── title_cache.txt             # Default title cache file
│       ├── LICENSE                     # License file
│       └── README.md                   # The file you are reading
└── script-opts/
    └── mpv-auto-torrent-title.conf     # Configuration file to edit as desired
```

## Updating

If enabled (default) the script checks for updates: if a new version is found, the script will notify the user.  

To update:  
1. **Git**: Navigate to the scripts directory and run git pull.  
   **Manual**: Download the latest release and replace the script folder in your scripts directory.
2. If the file mpv-auto-torrent-title.conf has been updated, you may need to delete your previously installed one in your script-opts directory, by doing so the updated .conf file will be installed at MPV next launch.

## How It Works

1.  **Detection**: When a file loads, the script checks if the path matches a torrent pattern (magnet link or localhost stream).
2.  **Fetch**: It sends a request with the torrent InfoHash to the configured endpoint.
3.  **Process**: The server returns the metadata and the script outputs the clean title to MPV.
4.  **Set**: The script updates `force-media-title` in MPV and caches the result (if enabled).

## Torrent Metadata Server

If you do not use Stremio, or want a robust fallback when Stremio is closed, this script supports **torrent-metadata**. This is a standalone Node.js server that scrapes metadata for a given InfoHash: you can either remotely use the public endpoit or run the local server on your machine.

### Remote:

#### Configure the Script
Edit `mpv-auto-torrent-title.conf` to use the remote server:

```conf
use_stremio_service=no           # Disable Stremio (or keep yes and use fallback below)
use_local_server=no              # Ensures you use the public endpoint only
```

### Local:

#### 1. Setup torrent-metadata
Follow the instructions here: https://github.com/schardev/torrent-metadata  
**Note**: On Windows you may need [cross-env](https://www.npmjs.com/package/cross-env) to make it work.

#### 2. Configure the Script
Edit `mpv-auto-torrent-title.conf` to point to your local server path:

```conf
use_stremio_service=no                            # Disable Stremio (or keep yes and use fallback below)
use_local_server=yes                              # Enable local server
server_path=...\torrent-metadata\packages\server  # Your torrent-metadata server package directory
local_server_url=http://localhost:3001            # 3001 should be the default port, change it to macth if needed
stop_server_on_exit=yes                           # Automatically kill the node process when MPV closes
```

**Functionality:**
*   The script will automatically start the Node.js server in the background when MPV launches a torrent.
*   It queries the local torrent-metadata server for title info.
*   It cleanly shuts down the server when MPV exits (if enabled).

## Notes

* Generally using stremio is faster that the torrent-metadata public endpoint which is faster than using the local server unless it's not already running.
* The local server killing on MPV shutdown might also kill other node.js processes, it depends on your system.
* Trimming functionality is not very consistent right now.

## Support

If you encounter any problems or have suggestions, please [open an issue](https://github.com/ExiledEye/mpv-auto-torrent-title/issues).

## License

Copyright (c) 2026 Exiled Eye  
This project is licensed under the MPL-2.0 License.  
Refer to the [LICENSE](LICENSE) file for details.
