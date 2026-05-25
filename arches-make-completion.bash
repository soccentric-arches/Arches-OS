# Bash completion for the Arches Yocto/kas Makefile
#
# Source this file or drop it in /etc/bash_completion.d/ :
#   source /path/to/arches/arches-make-completion.bash
#
# Or add to ~/.bashrc:
#   source ~/work/arches/arches-make-completion.bash
#
# Usage:
#   make image  jetson-orin-nano        ← board as positional arg
#   make sdk    jetson-orin-nano
#   make esdk   jetson-orin-nano
#   make flash  jetson-orin-nano DEVICE=/dev/sdb

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_arches_make_boards() {
    # Board names derived dynamically from kas/boards/*.yaml
    local kas_dir
    kas_dir="$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null)/kas"
    [[ -d "$kas_dir" ]] || kas_dir="$(pwd)/kas"
    find "$kas_dir/boards" -maxdepth 1 -name '*.yaml' \
        -exec basename {} .yaml \; 2>/dev/null | sort
}

# Targets that accept a board name as the next positional argument
_arches_board_targets="image build rebuild-image sdk esdk sdk-image esdk-image shell swu flash"

# ---------------------------------------------------------------------------
# Main completion function
# ---------------------------------------------------------------------------

_arches_make() {
    local cur prev words cword
    _init_completion || return

    local targets="
        image build rebuild-image
        sdk esdk sdk-image esdk-image
        kas-image ensure-image ensure-sdk-image ensure-esdk-image
        shell flash swu
        deploy-images deploy-sdk deploy-esdk deploy-swu
        clean clean-build clean-docker clean-all
        completion help
    "

    # -----------------------------------------------------------------------
    # Positional board argument:
    #   make image <TAB>  →  board names
    #   make sdk   <TAB>  →  board names
    # -----------------------------------------------------------------------
    if [[ $cword -eq 2 ]]; then
        local first_target="${words[1]}"
        if [[ " $_arches_board_targets " == *" $first_target "* ]]; then
            COMPREPLY=( $(compgen -W "$(_arches_make_boards)" -- "$cur") )
            return
        fi
    fi

    # -----------------------------------------------------------------------
    # Default: complete target names only
    # -----------------------------------------------------------------------
    COMPREPLY=( $(compgen -W "$targets" -- "$cur") )
} && complete -F _arches_make make
