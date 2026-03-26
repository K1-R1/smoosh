#compdef smoosh

_smoosh() {
  local -a args

  args=(
    '--docs[Include documentation files]'
    '--code[Include docs and all code files]'
    '--all[Include everything tracked by git (excluding binaries)]'
    '--only=[Restrict to matching extensions]:glob pattern: '
    '--include=[Add extensions to current mode]:glob pattern: '
    '--exclude=[Exclude matching paths]:glob pattern: '
    '--include-hidden[Include dotfiles and dot-directories]'
    '--output-dir=[Output directory]:directory:_files -/'
    '--max-words=[Words per output chunk]:number: '
    '--format=[Output format]:format:(md text xml)'
    '--toc[Add a table of contents to each chunk]'
    '--line-numbers[Prefix each line with its line number]'
    '--no-check-secrets[Skip the basic secrets scan]'
    '--dry-run[Preview only, no output files written]'
    '--quiet[Print output paths only]'
    '--json[Structured JSON to stdout]'
    '--no-interactive[Skip interactive mode]'
    '--no-color[Disable colour output]'
    '(-h --help)'{-h,--help}'[Print full usage]'
    '--version[Print version]'
    '*:file:_files'
  )

  _arguments -s -S $args
}

_smoosh "$@"
