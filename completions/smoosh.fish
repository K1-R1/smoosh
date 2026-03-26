# fish completion for smoosh

complete -c smoosh -f

complete -c smoosh -l docs -d 'Include documentation files'
complete -c smoosh -l code -d 'Include docs and all code files'
complete -c smoosh -l all -d 'Include everything tracked by git (excluding binaries)'
complete -c smoosh -l only -r -d 'Restrict to matching extensions'
complete -c smoosh -l include -r -d 'Add extensions to current mode'
complete -c smoosh -l exclude -r -d 'Exclude matching paths'
complete -c smoosh -l include-hidden -d 'Include dotfiles and dot-directories'
complete -c smoosh -l output-dir -x -a '(__fish_complete_directories)' -d 'Output directory'
complete -c smoosh -l max-words -x -d 'Words per output chunk'
complete -c smoosh -l format -x -a 'md text xml' -d 'Output format'
complete -c smoosh -l toc -d 'Add a table of contents to each chunk'
complete -c smoosh -l line-numbers -d 'Prefix each line with its line number'
complete -c smoosh -l no-check-secrets -d 'Skip the basic secrets scan'
complete -c smoosh -l dry-run -d 'Preview only, no output files written'
complete -c smoosh -l quiet -d 'Print output paths only'
complete -c smoosh -l json -d 'Structured JSON to stdout'
complete -c smoosh -l no-interactive -d 'Skip interactive mode'
complete -c smoosh -l no-color -d 'Disable colour output'
complete -c smoosh -l help -s h -d 'Print full usage'
complete -c smoosh -l version -d 'Print version'
