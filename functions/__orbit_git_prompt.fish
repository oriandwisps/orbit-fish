function __orbit_git_prompt --description 'Compact Nerd Font Git status for Orbit'
    command --query git
    or return 0

    # Do not refresh/write the index or run a configured filesystem-monitor hook.
    set -lx GIT_OPTIONAL_LOCKS 0
    set -l repo (command git rev-parse --git-dir --is-inside-git-dir --is-bare-repository 2>/dev/null)
    set -q repo[3]
    or return 0

    set -l git_dir $repo[1]
    set -l branch ''
    set -l oid ''
    set -l operation ''
    set -l staged 0
    set -l modified 0
    set -l untracked 0
    set -l conflicts 0
    set -l stash 0
    set -l ahead 0
    set -l behind 0

    if test "$repo[3]" = true
        set branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
        if test -z "$branch"
            set branch (command git rev-parse --short=8 HEAD 2>/dev/null)
        end
        set branch "BARE:$branch"
    else if test "$repo[2]" = true
        set branch 'GIT_DIR!'
    else
        # One status snapshot supplies branch, changes, stash, and upstream counts.
        # NUL-delimited records preserve unusual filenames, including newlines.
        set -l records (command git -c core.fsmonitor= status --porcelain=v2 --branch --show-stash --untracked-files=normal -z 2>/dev/null | string split0)
        set -l skip_origin 0
        for record in $records
            if test $skip_origin -eq 1
                set skip_origin 0
                continue
            end

            switch "$record"
                case '# branch.head *'
                    set branch (string sub --start 15 -- "$record")
                case '# branch.oid *'
                    set oid (string sub --start 14 -- "$record")
                case '# branch.ab *'
                    set -l counts (string split ' ' -- "$record")
                    set ahead (string sub --start 2 -- "$counts[3]")
                    set behind (string sub --start 2 -- "$counts[4]")
                case '# stash *'
                    set stash (string sub --start 9 -- "$record")
                case '1 *' '2 *'
                    set -l index_state (string sub --start 3 --length 1 -- "$record")
                    set -l worktree_state (string sub --start 4 --length 1 -- "$record")
                    if test "$index_state" != .
                        set staged (math "$staged + 1")
                    end
                    if test "$worktree_state" != .
                        set modified (math "$modified + 1")
                    end
                    # Renames have a second record containing just the old name.
                    string match --quiet '2 *' -- "$record"
                    and set skip_origin 1
                case 'u *'
                    set conflicts (math "$conflicts + 1")
                case '? *'
                    set untracked (math "$untracked + 1")
            end
        end

        if test "$branch" = '(detached)'
            set branch '('(string sub --length 8 -- "$oid")')'
        end

        if test -d "$git_dir/rebase-merge"; or test -d "$git_dir/rebase-apply"
            set operation REBASE
            if test -r "$git_dir/rebase-merge/head-name"
                read --local original_branch <"$git_dir/rebase-merge/head-name"
                set branch (string replace 'refs/heads/' '' -- "$original_branch")
            end
        else if test -f "$git_dir/MERGE_HEAD"
            set operation MERGE
        else if test -f "$git_dir/CHERRY_PICK_HEAD"
            set operation PICK
        else if test -f "$git_dir/REVERT_HEAD"
            set operation REVERT
        else if test -f "$git_dir/BISECT_LOG"
            set operation BISECT
        end
    end

    test -n "$branch"
    or return 0
    set branch (string replace --all --regex '[[:cntrl:]]' '' -- "$branch")
    set -l branch_width 24
    set -q argv[1]
    and set branch_width $argv[1]
    if test (string length --visible -- "$branch") -gt $branch_width
        set branch (string shorten --max $branch_width --char '…' -- "$branch")
    end

    # Follow fish_config colors without changing native Git-prompt settings.
    set -l normal (set_color --reset)
    set -l flags ''
    set -l amounts $staged $modified $untracked $conflicts $stash $ahead $behind
    set -l symbols '' '' '' '' '' '' ''
    set -l color_names fish_color_user fish_color_keyword fish_color_keyword fish_color_error fish_color_param fish_color_keyword fish_color_keyword
    for index in 1 2 3 4 5 6 7
        if test "$amounts[$index]" -gt 0
            set -l color_name $color_names[$index]
            set flags "$flags "(set_color $$color_name)"$symbols[$index]$amounts[$index]$normal"
        end
    end
    if test -n "$operation"
        set flags "$flags "(set_color $fish_color_error)" $operation$normal"
    end

    printf '%s%s%s%s' (set_color $fish_color_host) "$branch" "$normal" "$flags"
end
