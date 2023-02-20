# youtube-download
A userscript for MPV that allows you to download the current youtube video/audio with one key press.

Start a video download with ctrl+d (configurable) or start an audio download with ctrl+a (configurable).

## Installation

Copy youtube-download.lua into your scripts directory, e.g.:

    cp youtube-download.lua ~/.config/mpv/scripts/

optional, copy the config file:

    cp youtube-download.conf ~/.config/mpv/script-opts/

**Make sure you have either ffmpeg or avconv installed.**

### Windows:

The location of the scripts directory on Windows is `%APPDATA%\mpv\scripts` e.g. `C:\Users\cvzi\AppData\Roaming\mpv\scripts`
The location of the .conf files on Windows is `%APPDATA%\mpv\script-opts`

On windows, you need to [add the directory of the ffmpeg.exe to your machine's %PATH](https://stackoverflow.com/a/41895179/10367381)
or put the ffmpeg.exe in the same directory as the youtube-dl.exe/yt-dlp.

### [uosc](https://github.com/tomasklaen/uosc) menu integration

If you want to add the download menu to uosc, you need to add one of the following lines to your `input.conf`.
If you use the line starting with `#` it just creates an entry in the uosc menu.
If you use the second line, it also creates a keyboard shortcut to open the menu.
Replace `d` with the key of your choice:

```
#           script-message-to youtube_download menu     #! Download
OR
d           script-message-to youtube_download menu     #! Download
```

If you want it to appear in a submenu, replace `Download` with e.g. `Utils > Download`


Note: If you're using the default menu of uosc and you don't have the uosc menu defined in `input.conf`, you first need to create
a menu configuration. You can find an example at https://github.com/tomasklaen/uosc#examples

![screenshot of uosc](screenshot.gif)

### mpv.net:
The script folder for mpv.net is:
`%APPDATA%\mpv.net\scripts`

The .conf files belong into:
`%APPDATA%\mpv.net\script-opts`

The keyboard shortcuts in the script and the .conf-file don't work with mpv.net.
You need to set the keyboard shortcuts yourself in your `input.conf`. Default location is `%APPDATA%\mpv.net\input.conf`.
Add the following lines to the end of your `input.conf` (change the keys if they are already used, leave out lines that you don't need):

```

 Ctrl+d     script-message-to   youtube_download   download-video
 Ctrl+a     script-message-to   youtube_download   download-audio
 Ctrl+s     script-message-to   youtube_download   download-subtitle
 Ctrl+i     script-message-to   youtube_download   download-embed-subtitle

```

## Debugging errors:
To get more information in case of an error you can make mpv print more data about the script:
```bash
mpv --msg-level=youtube_download=trace "https://www.youtube.com/watch?v=AbC_DeFgHIj"
```
or on Windows:
```batch
mpv.com --msg-level=youtube_download=trace "https://www.youtube.com/watch?v=AbC_DeFgHIj"
```

## Features and default keyboard shortcuts:

*   CTRL + d : Download video
*   CTRL + a : Download audio
*   CTRL + s : Download subtitle
*   CTRL + i : Download video with embedded subtitle
*   To cancel a running download process, press any of the above key combinations **twice**
*   CTRL + r : Select an interval of start/end time to download only a portion of a video
    - Default interval: from current playing position til end
    - Use arrow keys to select another interval
    - Press CTRL + r again to fine tune second by second
    - Start download with CTRL + d, CTRL + a, ...
*   A download archive for youtube-dl can be set in the script configuration (disabled by default)
*   Cookies are picked up from `--ytdl-raw-options` or can be specified in the script configuration (disabled by default)
*   A log file for youtube-dl download errors can be set in the in the script configuration (disabled by default)
*   Choose between [youtube-dl](https://github.com/ytdl-org/youtube-dl/) or [yt-dlp](https://github.com/yt-dlp/yt-dlp). By default the script will try to auto-detect what is available and will prefer yt-dlp over youtube-dl. You can set the executable in the config to avoid the auto-detection.
*   (Windows only) Donwload command can open a new terminal to monitor the download progress

## Credit
- I pretty much copied the [mpv-youtube-quality](https://github.com/jgreco/mpv-youtube-quality) script

## [youtube-quality](https://github.com/jgreco/mpv-youtube-quality)'s Credit
- [reload.lua](https://github.com/4e6/mpv-reload/), for the function to reload a video while preserving the playlist.
- [mpv-playlistmanager](https://github.com/jonniek/mpv-playlistmanager), from which I ripped off much of the menu formatting config.
- ytdl_hook.lua, from which I ripped off much of the youtube-dl code to fetch the format list
- somebody on /mpv/ for the idea
