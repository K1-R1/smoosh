# smoosh demo — interactive mode (hero)
# Record with: vhs assets/demo.tape
# Requires: brew install vhs

Output assets/demo.gif

Require bash

Set Shell "bash"
Set FontSize 16
Set Width 1000
Set Height 800
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 60ms
Set PlaybackSpeed 1
Set WindowBar Colorful
Set Framerate 30

# --- Hidden setup ---
Hide
Type 'export PS1="$ "'
Enter
Type "rm -rf _smooshes/"
Enter
Sleep 300ms
Type "clear"
Enter
Sleep 300ms
Show

# Run smoosh with no arguments — triggers interactive mode.
# Banner, scan table, and menu appear automatically.
Type "./smoosh"
Sleep 500ms
Enter

# Pause so the viewer can read the banner, scan table, and menu.
Sleep 4s

# Pick option 2: Docs + Code — this triggers secrets detection,
# which is the most visually interesting flow.
Type "2"
Sleep 300ms
Enter

# Secrets warning, processing, verification tick, and summary.
Sleep 5s

# Peek inside the generated output.
Type "head -20 _smooshes/*.md"
Sleep 500ms
Enter
Sleep 4s

Sleep 2s
