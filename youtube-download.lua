-- youtube-download.lua
--
-- Download video/audio from youtube via youtube-dl and ffmpeg/avconv
-- This is forked/based on https://github.com/jgreco/mpv-youtube-quality
--
-- Video download bound to ctrl-d by default.
-- Audio download bound to ctrl-a by default.

-- Requires youtube-dl in PATH for video download
-- Requires ffmpeg or avconv in PATH for audio download

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'

local opts = {
    -- Key bindings
    -- Set to empty string "" to disable
    download_video_binding = "ctrl+d",
    download_audio_binding = "ctrl+a",

    -- Specify audio format: "best", "aac","flac", "mp3", "m4a", "opus", "vorbis", or "wav"
    audio_format = "mp3",

    -- Specify ffmpeg/avconv audio quality
    -- insert a value between 0 (better) and 9 (worse) for VBR or a specific bitrate like 128K
    audio_quality = "0",

    -- Same as youtube-dl --format FORMAT
    -- see https://github.com/ytdl-org/youtube-dl/blob/master/README.md#format-selection
    video_format = "",

    -- Encode the video to another format if necessary: "mp4", "flv", "ogg", "webm", "mkv", "avi"
    recode_video = "",

    -- Restrict filenames to only ASCII characters, and avoid "&" and spaces in filenames
    restrict_filenames = true,

    -- Download the whole playlist (false) or only one video (true)
    -- Same as youtube-dl --no-playlist
    no_playlist = true,

    -- Use an archive file, see youtube-dl --download-archive
    -- You have these options:
    --  * Set to empty string "" to not use an archive file
    --  * Set an absolute path to use one archive for all downloads e.g. download_archive="/home/user/archive.txt"
    --  * Set a relative path/only a filename to use one archive per directory e.g. download_archive="archive.txt"
    --  * Use $PLAYLIST to create one archive per playlist e.g. download_archive="/home/user/archives/$PLAYLIST.txt"
    download_archive = "",

    -- Use a cookies file for youtube-dl
    -- Same as youtube-dl --cookies
    -- On Windows you need to use a double blackslash or a single fordwardslash
    -- For example "C:\\Users\\Username\\cookies.txt"
    -- Or "C:/Users/Username/cookies.txt"
    cookies = "",

    -- Filename or full path
    -- Same as youtube-dl -o FILETEMPLATE
    -- see https://github.com/ytdl-org/youtube-dl/blob/master/README.md#output-template
    -- A relative path or a file name is relative to the path mpv was launched from
    -- On Windows you need to use a double blackslash or a single fordwardslash
    -- For example "C:\\Users\\Username\\Downloads\\%(title)s.%(ext)s"
    -- Or "C:/Users/Username/Downloads/%(title)s.%(ext)s"
    filename = "%(title)s.%(ext)s"
}

--Read configuration file
(require 'mp.options').read_options(opts, "youtube-download")

local function exec(args, capture_stdout, capture_stderr)
    local ret = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = capture_stdout or false,
        capture_stderr = capture_stderr or true,
        args = args,
    })
    return ret.status, ret.stdout, ret.stderr, ret
end

local function path_separator()
    return package.config:sub(1,1)
end

local function path_join(...)
    return table.concat({...}, path_separator())
end

local is_downloading = false
local function download(audio_only)
    msg.verbose("download()")
    if is_downloading then
        return
    end
    is_downloading = true
    msg.verbose("download() aquired")

    local url = mp.get_property("path")

    url = string.gsub(url, "ytdl://", "") -- Strip possible ytdl:// prefix.

    if string.find(url, "//youtu.be/") == nil
    and string.find(url, "//ww.youtu.be/") == nil
    and string.find(url, "//youtube.com/") == nil
    and string.find(url, "//www.youtube.com/") == nil
    then
        mp.osd_message("Not a youtube URL: " .. tostring(url), 10)
        is_downloading = false
        return
    end

    local list_match = url:match("list=(%w+)")
    local download_archive = opts.download_archive
    if list_match ~= nil and opts.download_archive ~= nil and opts.download_archive:find("$PLAYLIST", 1, true) then
        download_archive = opts.download_archive:gsub("$PLAYLIST", list_match)
    end

    if audio_only then
        mp.osd_message("Audio download started", 2)
    else
        mp.osd_message("Video download started", 2)
    end

    -- Compose command line arguments
    local command = {"youtube-dl", "--no-overwrites"}
    if opts.restrict_filenames then
      table.insert(command, "--restrict-filenames")
    end
    if opts.filename and opts.filename ~= "" then
        table.insert(command, "-o")
        table.insert(command, opts.filename)
    end
    if opts.no_playlist then
        table.insert(command, "--no-playlist")
    end
    if download_archive and download_archive ~= "" then
        table.insert(command, "--download-archive")
        table.insert(command, download_archive)
    end
    if audio_only then
        table.insert(command, "--extract-audio")
        if opts.audio_format and opts.audio_format  ~= "" then
          table.insert(command, "--audio-format")
          table.insert(command, opts.audio_format)
        end
        if opts.audio_quality and opts.audio_quality  ~= "" then
          table.insert(command, "--audio-quality")
          table.insert(command, opts.audio_quality)
        end
    else
        if opts.video_format and opts.video_format  ~= "" then
          table.insert(command, "--format")
          table.insert(command, opts.video_format)
        end
        if opts.recode_video and opts.recode_video  ~= "" then
          table.insert(command, "--recode-video")
          table.insert(command, opts.recode_video)
        end
    end
    if opts.cookies and opts.cookies  ~= "" and opts.cookies:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
        table.insert(command, "--cookies")
        table.insert(command, opts.cookies)
    end
    table.insert(command, url)

    -- Start download
    local status, stdout, stderr = exec(command, true, true)

    is_downloading = false

    if (status ~= 0) then
        mp.osd_message("download failed:\n" .. tostring(stderr), 10)
        msg.error("URL: " .. tostring(url))
        msg.error("Return status code: " .. tostring(status))
        msg.verbose(tostring(stderr))
        msg.verbose(tostring(stdout))
        return
    end

    if string.find(stdout, "has already been recorded in archive") ~=nil then
        mp.osd_message("Has already been recorded in archive", 5)
        return
    end


    -- Retrieve the file name
    local filename = nil
    if stdout then
        local i, j, last_i, start_index = 0
        while i ~= nil do
            last_i, start_index = i, j
            i, j = stdout:find ("Destination: ",j, true)
        end

        if last_i ~= nil then
          local end_index = stdout:find ("\n", start_index, true)
          if end_index ~= nil and start_index ~= nil then
            filename = stdout:sub(start_index, end_index):gsub("^%s+", ""):gsub("%s+$", "")
           end
        end
    end

    if filename then
        local filepath
        local basepath
        if filename:find("/") == nil and filename:find("\\") == nil then
          basepath = utils.getcwd()
          filepath = path_join(utils.getcwd(), filename)
        else
          basepath = ""
          filepath = filename
        end

        local osd_text
        local ass0 = mp.get_property("osd-ass-cc/0")
        local ass1 =  mp.get_property("osd-ass-cc/1")
        if filepath:len() < 100 then
            osd_text = ass0 .. "{\\fs12} " .. filepath .. " {\\fs20}" .. ass1
        elseif basepath == "" then
            osd_text = ass0 .. "{\\fs8} " .. filepath .. " {\\fs20}" .. ass1
        else
            osd_text = ass0 .. "{\\fs11} " .. basepath .. "\n" .. filename .. " {\\fs20}" ..  ass1
        end
        mp.osd_message("Download succeeded\n" .. osd_text, 5)
    else
        mp.osd_message("Download succeeded\n" .. utils.getcwd(), 5)
    end
end

local function download_video()
    return download(false)
end

local function download_audio()
    return download(true)
end

-- keybind
if opts.download_video_binding and opts.download_video_binding ~= "" then
    mp.add_key_binding(opts.download_video_binding, "download-video", download_video)
end
if opts.download_audio_binding and opts.download_audio_binding ~= "" then
    mp.add_key_binding(opts.download_audio_binding, "download-audio", download_audio)
end