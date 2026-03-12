#!/usr/bin/env fish

# List directories in the current directory
set dirs (ls -d */)

# Check the number of directories
set dir_count (count $dirs)

if test $dir_count -gt 1
    # Use fzf for interactive folder selection
    set choice (printf "%s\n" "(stay in current folder)" $dirs | fzf --height=~50% --reverse --prompt="Select folder: ")

    if test -z "$choice"
        echo "No selection made"
        return
    else if test "$choice" != "(stay in current folder)"
        cd $choice
        echo "Changed directory to $choice"
    end
else if test $dir_count -eq 1
    cd $dirs[1]
    echo "Changed directory to $dirs[1]"
end

# Action selection
set action (printf "%s\n" \
    "Open in VS Code" \
    "Open in Claude Code" \
    "Open in Lazygit" \
    "Open in terminal" \
    "Open in file manager" \
    "Git status" \
    | fzf --height=~50% --reverse --prompt="Action: ")

switch "$action"
    case "Open in VS Code"
        code .
    case "Open in Claude Code"
        claude
    case "Open in Lazygit"
        lazygit
    case "Open in terminal"
        echo "Ready in (pwd)"
    case "Open in file manager"
        xdg-open .
    case "Git status"
        git -c color.status=always status
    case "*"
        echo "No action selected"
end
