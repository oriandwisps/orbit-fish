function fish_prompt --description 'Orbit: two-line Nerd Font status and command prompt'
    # Capture both before any command changes status (including a failed pipeline).
    set -l previous $status $pipestatus
    set -l duration_ms "$CMD_DURATION"

    set -l normal (set_color --reset)
    set -l frame (set_color $fish_color_autosuggestion)
    set -l success (set_color $fish_color_user)
    set -l error (set_color $fish_color_error)
    set -l accent (set_color $fish_color_keyword)
    set -l cwd_color (set_color $fish_color_cwd)
    set -l arrow_color $cwd_color
    set -l failed 0

    for code in $previous
        if test "$code" -ne 0
            set failed 1
            break
        end
    end

    # Put exit status first so it remains visible when the top line is shortened.
    set -l marker "$success"
    if test $failed -eq 1
        set -l exit_code $previous[1]
        if test (count $previous) -gt 2
            set exit_code (string join '|' -- $previous[2..])
        end
        set marker "$error $exit_code"
        set arrow_color $error
    end
    set -l top "$normal$frame╭─ $marker$normal"

    if fish_is_root_user
        set cwd_color (set_color $fish_color_cwd_root)
        set arrow_color $error
        set top "$top  $error root$normal"
    end

    # fish_mode_prompt is silent; vi/hybrid mode belongs on the status line.
    if contains -- "$fish_key_bindings" fish_vi_key_bindings fish_hybrid_key_bindings
        set -l mode ' N'
        switch $fish_bind_mode
            case insert
                set mode ' I'
            case visual
                set mode ' V'
            case replace replace_one
                set mode ' R'
        end
        set top "$top  $accent$mode$normal"
    end

    if set -q SSH_CONNECTION; or set -q SSH_TTY
        set -l host (prompt_hostname | string replace --all --regex '[[:cntrl:]]' '')
        set top "$top  "(set_color $fish_color_host_remote)" $host$normal"
    end

    # Keep the last two directory components readable and abbreviate their parents.
    set -l cwd (prompt_pwd --dir-length=1 --full-length-dirs=2)
    set top "$top  $cwd_color $cwd$normal"

    set -l width 78
    if set -q COLUMNS; and string match --quiet --regex '^[0-9]+$' -- "$COLUMNS"
        set width (math "max(4, $COLUMNS - 2)")
    end
    set -l branch_width (math --scale=0 "max(8, min(24, $width / 3))")
    set -l git_status (__orbit_git_prompt $branch_width)
    if test -n "$git_status"
        set top "$top  "(set_color $fish_color_host)" $git_status$normal"
    end

    # Hide timing for fast commands; show seconds or minutes for slower commands.
    if string match --quiet --regex '^[0-9]+$' -- "$duration_ms"; and test "$duration_ms" -ge 1000
        set -l elapsed (math --scale=1 "$duration_ms / 1000")s
        if test "$duration_ms" -ge 60000
            set -l minutes (math --scale=0 "$duration_ms / 60000")
            set -l seconds (math --scale=0 "($duration_ms / 1000) % 60")
            set elapsed "$minutes"m"$seconds"s
        end
        set top "$top  $accent $elapsed$normal"
    end

    if jobs --query
        set -l job_count (count (jobs --pid))
        set top "$top  "(set_color $fish_color_param)" $job_count$normal"
    end

    # string shorten measures terminal columns and ignores ANSI color escapes.
    # Always reset afterward: shortening can remove a color's closing reset.
    if test (string length --visible -- "$top") -gt $width
        set top (string shorten --no-newline --max $width --char '…' -- "$top")
    end
    # Separate command/output blocks with one blank line.
    printf '%s\n%s%s\n' "$normal" "$top" "$normal"
    printf '%s╰─ %s %s' "$frame" "$arrow_color" "$normal"
end
