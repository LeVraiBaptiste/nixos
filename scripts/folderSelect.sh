#!/usr/bin/env fish

# List directories in the current directory
set dirs (ls -d */)

# Display the directories
echo "Directories in the current directory:"
for i in (seq (count $dirs))
    echo "$i. $dirs[$i]"
end

# Prompt the user to choose a directory
echo -n "Enter the number of the directory you want to go to: "
read choice

# Change to the chosen directory
if test $choice -le (count $dirs) -a $choice -gt 0
    cd $dirs[$choice]
    echo "Changed directory to $dirs[$choice]"
else
    echo "Invalid choice"
end