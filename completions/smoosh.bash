#!/usr/bin/env bash

_smoosh_completions() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  opts="--docs --code --all --only --include --exclude --include-hidden \
        --output-dir --max-words --format --toc --line-numbers \
        --no-check-secrets --dry-run --quiet --json --no-color \
        --no-interactive --help -h --version"

  case "${prev}" in
    --format)
      COMPREPLY=( $(compgen -W "md text xml" -- "${cur}") )
      return 0
      ;;
    --output-dir)
      compopt -o dirnames
      COMPREPLY=( $(compgen -d -- "${cur}") )
      return 0
      ;;
  esac

  if [[ ${cur} == -* ]] ; then
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
  fi
  
  # Default to file/dir completion
  compopt -o default
  COMPREPLY=()
}

complete -F _smoosh_completions smoosh
