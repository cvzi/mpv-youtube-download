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
    download_subtitle_binding = "ctrl+s",
    download_video_embed_subtitle_binding = "ctrl+i",
    select_range_binding = "ctrl+r",

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
    filename = "%(title)s.%(ext)s",

    -- Subtitle language
    -- Same as youtube-dl --sub-lang en
    sub_lang = "en",

    -- Subtitle format
    -- Same as youtube-dl --sub-format best
    sub_format = "best",

    -- Log file for download errors
    log_file = "",

}

--Read configuration file
(require 'mp.options').read_options(opts, "youtube-download")

--Read command line arguments
local ytdl_raw_options = mp.get_property("ytdl-raw-options")
if ytdl_raw_options ~= nil and ytdl_raw_options:find("cookies=") ~= nil then
    local cookie_file = ytdl_raw_options:match("cookies=([^,]+)")
    if cookie_file ~= nil then
        opts.cookies = cookie_file
    end
end

local function exec(args, capture_stdout, capture_stderr)
    local ret = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = capture_stdout,
        capture_stderr = capture_stderr,
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

local DOWNLOAD = {
    VIDEO=1,
    AUDIO=2,
    SUBTITLE=3,
    VIDEO_EMBED_SUBTITLE=4
}
local select_range_mode = 0
local start_time_seconds = nil
local start_time_formated = nil
local end_time_seconds = nil
local end_time_formated = nil

local is_downloading = false
local function download(download_type)
    local start_time = os.date("%c")
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

    if download_type == DOWNLOAD.AUDIO then
        mp.osd_message("Audio download started", 2)
    elseif download_type == DOWNLOAD.SUBTITLE then
        mp.osd_message("Subtitle download started", 2)
    elseif download_type == DOWNLOAD.VIDEO_EMBED_SUBTITLE then
        mp.osd_message("Video w/ subtitle download started", 2)
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

    if download_type == DOWNLOAD.SUBTITLE then
        table.insert(command, "--sub-lang")
        table.insert(command, opts.sub_lang)
        table.insert(command, "--write-sub")
        table.insert(command, "--skip-download")
        if opts.sub_format and opts.sub_format  ~= "" then
            table.insert(command, "--sub-format")
            table.insert(command, opts.sub_format)
        end
    elseif download_type == DOWNLOAD.AUDIO then
        table.insert(command, "--extract-audio")
        if opts.audio_format and opts.audio_format  ~= "" then
          table.insert(command, "--audio-format")
          table.insert(command, opts.audio_format)
        end
        if opts.audio_quality and opts.audio_quality  ~= "" then
          table.insert(command, "--audio-quality")
          table.insert(command, opts.audio_quality)
        end
    else --DOWNLOAD.VIDEO or DOWNLOAD.VIDEO_EMBED_SUBTITLE
        if download_type == DOWNLOAD.VIDEO_EMBED_SUBTITLE then
            table.insert(command, "--all-subs")
            table.insert(command, "--write-sub")
            table.insert(command, "--embed-subs")
            if opts.sub_format and opts.sub_format  ~= "" then
                table.insert(command, "--sub-format")
                table.insert(command, opts.sub_format)
            end
        end
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
    if select_range_mode > 0 then
         table.insert(command, "--external-downloader")
         table.insert(command, "ffmpeg")
         table.insert(command, "--external-downloader-args")
         table.insert(command, "-ss ".. tostring(start_time_seconds) .. " -to " .. tostring(end_time_seconds))
         select_range_mode = 0
    end

    table.insert(command, url)

    -- Show download indicator
    mp.set_osd_ass(0, 0, "{\\an9}{\\fs12}⌛💾")

    -- Start download
    msg.debug("exec: " .. table.concat(command, " "))
    local status, stdout, stderr = exec(command, true, true)

    is_downloading = false

    -- Hide download indicator
    mp.set_osd_ass(0, 0, "")

    local wrote_error_log = false
    if stderr ~= nil and opts.log_file ~= "" and stderr:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
        -- Write stderr to log file
        local title = mp.get_property("media-title")
        local file = io.open (opts.log_file , "a+")
        file:write("\n[")
        file:write(start_time)
        file:write("] ")
        file:write(url)
        file:write("\n[\"")
        file:write(title)
        file:write("\"]\n")
        file:write(stderr)
        file:close()
        wrote_error_log = true
    end

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

    local osd_text = "Download succeeded\n"
    local osd_time = 5
    local ass0 = mp.get_property("osd-ass-cc/0")
    local ass1 =  mp.get_property("osd-ass-cc/1")
    -- Find filename or directory
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

        if filepath:len() < 100 then
            osd_text = osd_text .. ass0 .. "{\\fs12} " .. filepath .. " {\\fs20}" .. ass1
        elseif basepath == "" then
            osd_text = osd_text .. ass0 .. "{\\fs8} " .. filepath .. " {\\fs20}" .. ass1
        else
            osd_text = osd_text .. ass0 .. "{\\fs11} " .. basepath .. "\n" .. filename .. " {\\fs20}" ..  ass1
        end
        if wrote_error_log then
            -- Write filename and end time to log file
            local file = io.open (opts.log_file , "a+")
            file:write("[" .. filepath .. "]\n")
            file:write(os.date("[end %c]\n"))
            file:close()
        end
    else
        if wrote_error_log then
            -- Write directory and end time to log file
            local file = io.open (opts.log_file , "a+")
            file:write("[" .. utils.getcwd() .. "]\n")
            file:write(os.date("[end %c]\n"))
            file:close()
        end
        osd_text = osd_text .. utils.getcwd()
    end

    -- Show warnings
    if stderr ~= nil and stderr:gsub("^%s+", ""):gsub("%s+$", "") ~= "" then
        msg.warn("Errorlog:" .. tostring(stderr))
        if stderr:find("incompatible for merge") == nil then
            osd_text = osd_text .. "\n" .. ass0 .. "{\\fs9} " .. stderr .. ass1
            osd_time = osd_time + 5
        end
    end

    mp.osd_message(osd_text, osd_time)
end

local function select_range_show()
    local status
    if select_range_mode > 0 then
        if select_range_mode == 2 then
            status = "Download interval: Fine tune\n← → start time\n↓ ↑ end time\n" ..
                tostring(opts.select_range_binding) .. " next mode"
        elseif select_range_mode == 1 then
            status = "Download interval: Select range\n← start here\n→ end here\n↓from beginning\n↑til end\n" ..
                tostring(opts.select_range_binding) .. " next mode"
        end
        mp.osd_message("Start: " .. start_time_formated .. "\nEnd:  " .. end_time_formated .. "\n" .. status, 30)
    else
        status = "Range interval: Disabled (download full length)"
        mp.osd_message(status, 3)
    end
end

local function select_range_set_left()
    if select_range_mode == 2 then
        start_time_seconds = math.max(0, start_time_seconds - 1)
        if start_time_seconds < 86400 then
            start_time_formated = os.date("!%H:%M:%S", start_time_seconds)
        else
            start_time_formated = tostring(start_time_seconds) .. "s"
        end
    elseif select_range_mode == 1 then
        start_time_seconds = mp.get_property_number("time-pos")
        start_time_formated = mp.command_native({"expand-text","${time-pos}"})
    end
    select_range_show()
end

local function select_range_set_start()
    if select_range_mode == 2 then
        end_time_seconds = math.max(1, end_time_seconds - 1)
        if end_time_seconds < 86400 then
            end_time_formated = os.date("!%H:%M:%S", end_time_seconds)
        else
            end_time_formated = tostring(end_time_seconds) .. "s"
        end
    elseif select_range_mode == 1 then
        start_time_seconds = 0
        start_time_formated = "00:00:00"
    end
    select_range_show()
end

local function select_range_set_end()
    if select_range_mode == 2 then
        end_time_seconds = math.min(mp.get_property_number("duration"), end_time_seconds + 1)
        if end_time_seconds < 86400 then
            end_time_formated = os.date("!%H:%M:%S", end_time_seconds)
        else
            end_time_formated = tostring(end_time_seconds) .. "s"
        end
    elseif select_range_mode == 1 then
        end_time_seconds = mp.get_property_number("duration")
        end_time_formated =  mp.command_native({"expand-text","${duration}"})
    end
    select_range_show()
end

local function select_range_set_right()
    if select_range_mode == 2 then
        start_time_seconds = math.min(mp.get_property_number("duration") - 1, start_time_seconds + 1)
        if start_time_seconds < 86400 then
            start_time_formated = os.date("!%H:%M:%S", start_time_seconds)
        else
            start_time_formated = tostring(start_time_seconds) .. "s"
        end
    elseif select_range_mode == 1 then
        end_time_seconds = mp.get_property_number("time-pos")
        end_time_formated = mp.command_native({"expand-text","${time-pos}"})
    end
    select_range_show()
end

local function select_range()
    -- Cycle through modes
    if select_range_mode == 2 then
        -- Disable range mode
        select_range_mode = 0
        -- Remove the arrow key key bindings
        mp.remove_key_binding("select-range-set-up")
        mp.remove_key_binding("select-range-set-down")
        mp.remove_key_binding("select-range-set-left")
        mp.remove_key_binding("select-range-set-right")
    elseif select_range_mode == 1 then
        -- Switch to "fine tune" mode
        select_range_mode = 2
    else
        select_range_mode = 1
        -- Add keybinds for arrow keys
        mp.add_key_binding("up", "select-range-set-up", select_range_set_end)
        mp.add_key_binding("down", "select-range-set-down", select_range_set_start)
        mp.add_key_binding("left", "select-range-set-left", select_range_set_left)
        mp.add_key_binding("right", "select-range-set-right", select_range_set_right)

        -- Defaults
        if start_time_seconds == nil then
            start_time_seconds = mp.get_property_number("time-pos")
            start_time_formated = mp.command_native({"expand-text","${time-pos}"})
            end_time_seconds = mp.get_property_number("duration")
            end_time_formated =  mp.command_native({"expand-text","${duration}"})
        end
    end
    select_range_show()
end

local function download_video()
    return download(DOWNLOAD.VIDEO)
end

local function download_audio()
    return download(DOWNLOAD.AUDIO)
end

local function download_subtitle()
    return download(DOWNLOAD.SUBTITLE)
end

local function download_embed_subtitle()
    return download(DOWNLOAD.VIDEO_EMBED_SUBTITLE)
end

-- keybind
if opts.download_video_binding and opts.download_video_binding ~= "" then
    mp.add_key_binding(opts.download_video_binding, "download-video", download_video)
end
if opts.download_audio_binding and opts.download_audio_binding ~= "" then
    mp.add_key_binding(opts.download_audio_binding, "download-audio", download_audio)
end
if opts.download_subtitle_binding and opts.download_subtitle_binding ~= "" then
    mp.add_key_binding(opts.download_subtitle_binding, "download-subtitle", download_subtitle)
end
if opts.download_video_embed_subtitle_binding and opts.download_video_embed_subtitle_binding ~= "" then
    mp.add_key_binding(opts.download_video_embed_subtitle_binding, "download-embed-subtitle", download_embed_subtitle)
end
if opts.select_range_binding and opts.select_range_binding ~= "" then
    mp.add_key_binding(opts.select_range_binding, "select-range-start", select_range)
end
