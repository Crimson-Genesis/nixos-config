{
  xdg.configFile."dunst/dunstrc".text = ''
    [global]
        width = 380
        height = 140

        origin = top-right
        offset = 20x20

        notification_limit = 10

        progress_bar = true
        progress_bar_height = 12
        progress_bar_frame_width = 0

        corner_radius = 12

        frame_width = 2
        frame_color = "#000000"

        separator_height = 2
        separator_color = frame

        # transparency = 30

        font = JetBrainsMono Nerd Font Mono 11

        alignment = left
        icon_position = left

        min_icon_size = 32
        max_icon_size = 64

        markup = full
        word_wrap = true

        mouse_left_click = close_current
        mouse_middle_click = do_action, close_current
        mouse_right_click = close_all

        timeout = 5

    [urgency_low]
        background = "#0b1f14b3"
        foreground = "#a6e3a1"
        frame_color = "#14532db3"
        timeout = 3

    [urgency_normal]
        background = "#000000b3"
        foreground = "#ffffff"
        frame_color = "#111111b3"
        timeout = 5

    [urgency_critical]
        background = "#220408b3"
        foreground = "#ffffff"
        frame_color = "#49010eb3"
        timeout = 0

    [error]
        appname = "error"
        summary = "Error"

        background = "#220408b3"
        foreground = "#ffffff"
        frame_color = "#49010eb3"
        timeout = 5
  '';
}
