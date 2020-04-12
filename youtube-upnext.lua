-- youtube-upnext.lua
--
-- Fetch upnext/recommended videos from youtube
-- This is forked/based on https://github.com/jgreco/mpv-youtube-quality
--
-- Diplays a menu that lets you load the upnext/recommended video from youtube
-- that appear on the right side on the youtube website.
-- If auto_add is set to true (default), the 'up next' video is automatically
-- appended to the current playlist
--
-- Bound to ctrl-u by default.
--
-- Requires wget/wget.exe in PATH. On Windows you may need to set check_certificate
-- to false, otherwise wget.exe might not be able to download the youtube website.

local mp = require 'mp'
local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local opts = {
    --key bindings
    toggle_menu_binding = "ctrl+u",
    up_binding = "UP",
    down_binding = "DOWN",
    select_binding = "ENTER",

    --auto load and add the "upnext" video to the playlist
    auto_add = true,

    --formatting / cursors
    cursor_selected   = "● ",
    cursor_unselected = "○ ",

    --font size scales by window, if false requires larger font and padding sizes
    scale_playlist_by_window=false,

    --playlist ass style overrides inside curly brackets, \keyvalue is one field, extra \ for escape in lua
    --example {\\fnUbuntu\\fs10\\b0\\bord1} equals: font=Ubuntu, size=10, bold=no, border=1
    --read http://docs.aegisub.org/3.2/ASS_Tags/ for reference of tags
    --undeclared tags will use default osd settings
    --these styles will be used for the whole playlist. More specific styling will need to be hacked in
    --
    --(a monospaced font is recommended but not required)
    style_ass_tags = "{\\fnmonospace}",

    --paddings for top left corner
    text_padding_x = 5,
    text_padding_y = 5,

    --other
    menu_timeout = 10,
    youtube_url = "https://www.youtube.com/watch?v=%s",
    check_certificate = true,
}
(require 'mp.options').read_options(opts, "youtube-upnext")

local destroyer = nil
upnext_cache={}
function on_file_loaded(event)
    local url = mp.get_property("path")
    url = string.gsub(url, "ytdl://", "") -- Strip possible ytdl:// prefix.
    if string.find(url, "youtu") ~= nil then
        local upnext, num_upnext = load_upnext()
        if num_upnext > 0 then
            mp.commandv("loadfile", upnext[1].file, "append")
        end
    end
end

function show_menu()
    mp.osd_message("fetching 'up next' with wget...", 60)

    local upnext, num_upnext = load_upnext()
    mp.osd_message("", 1)
    if num_upnext == 0 then
        return
    end

    local selected = 1
    function selected_move(amt)
        selected = selected + amt
        if selected < 1 then
            selected = num_upnext
        elseif selected > num_upnext then
            selected = 1
        end
        timeout:kill()
        timeout:resume()
        draw_menu()
    end
    function choose_prefix(i)
        if i == selected then
            return opts.cursor_selected
        else
            return opts.cursor_unselected
        end
    end

    function draw_menu()
        local ass = assdraw.ass_new()

        ass:pos(opts.text_padding_x, opts.text_padding_y)
        ass:append(opts.style_ass_tags)

        for i,v in ipairs(upnext) do
            ass:append(choose_prefix(i)..v.label.."\\N")
        end

      local w, h = mp.get_osd_size()
      if opts.scale_playlist_by_window then w,h = 0, 0 end
      mp.set_osd_ass(w, h, ass.text)
    end

    function destroy()
        timeout:kill()
        mp.set_osd_ass(0,0,"")
        mp.remove_key_binding("move_up")
        mp.remove_key_binding("move_down")
        mp.remove_key_binding("select")
        mp.remove_key_binding("escape")
        destroyer = nil
    end
    timeout = mp.add_periodic_timer(opts.menu_timeout, destroy)
    destroyer = destroy

    mp.add_forced_key_binding(opts.up_binding,     "move_up",   function() selected_move(-1) end, {repeatable=true})
    mp.add_forced_key_binding(opts.down_binding,   "move_down", function() selected_move(1)  end, {repeatable=true})
    mp.add_forced_key_binding(opts.select_binding, "select",    function()
        destroy()
        mp.commandv("loadfile", upnext[selected].file, "replace")
        reload_resume()
    end)
    mp.add_forced_key_binding(opts.toggle_menu_binding, "escape", destroy)

    draw_menu()
    return
end

function table_size(t)
    local s = 0
    for i,v in ipairs(t) do
        s = s+1
    end
    return s
end

function load_upnext()
    local url = mp.get_property("path")

    url = string.gsub(url, "ytdl://", "") -- Strip possible ytdl:// prefix.

    if string.find(url, "//youtu.be/") == nil
    and string.find(url, "//ww.youtu.be/") == nil
    and string.find(url, "//youtube.com/") == nil
    and string.find(url, "//www.youtube.com/") == nil
    then
        return {}, 0
    end

    -- don't fetch the website if it's already cached
    if upnext_cache[url] ~= nil then
        local res = upnext_cache[url]
        return res, table_size(res)
    end

    local res, n = parse_upnext(download_upnext(url), url)

    return res, n
end

function download_upnext(url)
    local function exec(args)
        local ret = utils.subprocess({args = args})
        return ret.status, ret.stdout, ret
    end

    local command = {"wget", "-q", "-O", "-"}
    if not opts.check_certificate then
        table.insert(command, "--no-check-certificate")
    end
    table.insert(command, url)

    local es, s, result = exec(command)

    if (es ~= 0) or (s == nil) or (s == "") then
        if es == 5 then
            mp.osd_message("upnext failed: wget does not support HTTPS", 10)
            msg.error("wget is missing certificates, disable check-certificate in userscript options")
        elseif es == -1 or es == 127 or es == 9009 then
            mp.osd_message("upnext failed: wget not found", 10)
            msg.error("wget/ wget.exe is missing. Please install it or put an executable in your PATH")
        else
            mp.osd_message("upnext failed: error=" .. tostring(es), 10)
            msg.error("failed to get upnext list: error=%s" .. tostring(es))
        end
        return "{}"
    end

    local pos1 = string.find(s, "watchNextEndScreenRenderer", 1, true)
    local pos2 = string.find(s, "}}}],\\\"", pos1 + 1, true)
    if pos1 == nil or pos2 == nil then
        mp.osd_message("upnext failed, no upnext data found", 10)
        msg.error("failed to get upnext data: pos1=" .. tostring(pos1) .. " pos2=" ..tostring(pos2))
    end
    s = string.sub(s, pos1, pos2)

    return "{\"" .. string.gsub(s, "\\\"", "\"") .. "}}]}}"
end

function parse_upnext(json_str, url)
    if json_str == "{}" then
      return {}, 0
    end

    local data, err = utils.parse_json(json_str)

    if data == nil then
        mp.osd_message("upnext failed: JSON decode failed", 10)
        msg.error("parse_json failed: " .. err)
        return {}, 0
    end

    local res = {}
    msg.verbose("wget and json decode succeeded!")
    for i, v in ipairs(data.watchNextEndScreenRenderer.results) do
        if v.endScreenVideoRenderer ~= nil and v.endScreenVideoRenderer.title ~= nil and v.endScreenVideoRenderer.title.simpleText ~= nil then
            local title = v.endScreenVideoRenderer.title.simpleText
            local video_id = v.endScreenVideoRenderer.videoId
            table.insert(res, {
                index=i,
                label=title,
                file=string.format(opts.youtube_url, video_id)
            })
        end
    end

    table.sort(res, function(a, b) return a.index < b.index end)

    upnext_cache[url] = res
    return res, table_size(res)
end


-- register script message to show menu
mp.register_script_message("toggle-upnext-menu",
function()
    if destroyer ~= nil then
        destroyer()
    else
        show_menu()
    end
end)

-- keybind to launch menu
mp.add_key_binding(opts.toggle_menu_binding, "upnext-menu", show_menu)

if opts.auto_add then
    mp.register_event("file-loaded", on_file_loaded)
end
