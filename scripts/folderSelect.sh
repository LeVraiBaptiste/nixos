#!/usr/bin/env fish

# List directories in the current directory
set dirs (ls -d */)

# Check the number of directories
set dir_count (count $dirs)

if test $dir_count -eq 1
    # If only one directory is present, change to it directly
    cd $dirs[1]
    echo "Changed directory to $dirs[1]"
else
    # Display the directories
    echo "Directories in the current directory:"
    for i in (seq $dir_count)
        echo "$i. $dirs[$i]"
    end

    # Prompt the user to choose a directory
    echo -n "Enter the number of the directory you want to go to: "
    read choice

    # Change to the chosen directory
    if test $choice -le $dir_count -a $choice -gt 0
        cd $dirs[$choice]
        echo "Changed directory to $dirs[$choice]"
    else
        echo "Invalid choice"
    end
end