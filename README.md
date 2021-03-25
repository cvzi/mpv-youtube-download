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
or put the ffmpeg.exe in the same directory as the youtube-dl.exe.

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

## Credit
- I pretty much copied the [mpv-youtube-quality](https://github.com/jgreco/mpv-youtube-quality) script

## [youtube-quality](https://github.com/jgreco/mpv-youtube-quality)'s Credit
- [reload.lua](https://github.com/4e6/mpv-reload/), for the function to reload a video while preserving the playlist.
- [mpv-playlistmanager](https://github.com/jonniek/mpv-playlistmanager), from which I ripped off much of the menu formatting config.
- ytdl_hook.lua, from which I ripped off much of the youtube-dl code to fetch the format list
- somebody on /mpv/ for the idea
