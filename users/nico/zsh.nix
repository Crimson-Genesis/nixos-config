{
  home.sessionVariables = {
    PYDEVD_DISABLE_FILE_VALIDATION = "1";
    TERMINAL = "alacritty";
    FZF_DEFAULT_OPTS = "--bind=alt-k:up,alt-j:down";
    PAGER = "less -FRX";
    BROWSER = "zen";
    LESS = "--use-color";
  };

  programs.starship = {
    enable = true;

    settings = {
      add_newline = false;

      format = ''
        $directory$git_branch$git_status$fill$status$cmd_duration$time
        $character
      '';

      directory = {
        truncation_length = 16;
        truncate_to_repo = true;
        read_only = "";
        style = "green";
        read_only_style = "red";
      };

      git_branch = {
        symbol = " ";
      };

      git_status = {
        disabled = false;
      };

      cmd_duration = {
        min_time = 1;
        format = "[$duration]($style) ";
        style = "bright-black";
      };

      status = {
        disabled = false;
        symbol = "✗";
        success_symbol = "";
        format = "[$symbol$status]($style) ";
        style = "#DC143C";
      };

      fill = {
        symbol = " ";
      };

      time = {
        disabled = false;
        time_format = "%H:%M:%S";
        format = "[$time]($style)";
        style = "bright-black";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    history = {
      size = 10000;
      save = 10000;
      path = "$HOME/.histfile";
    };

    shellAliases = {
      # eza:
      ".." = "cd ..";
      "ls" = "eza --icons --group-directories-first -l --hyperlink";
      "lss" = "eza --icons --group-directories-first -l --hyperlink --total-size";

      # trash-cli
      "trl" = "trash-list";
      "tre" = "trash-empty";
      "trp" = "trash-put";
      "trr" = "trash-restore";
      "rm" = "trash";

      # Scripts
      "cht" = "bash ~/.config/LSD/cht.sh";
      "yy" = ''function yy(){ local t=$(mktemp -t yazi-cwd.XXXXXX); yazi "$@" --cwd-file="$t"; local c=$(cat "$t"); [[ -n "$c" && "$c" != "$PWD" ]] && cd "$c"; rm -f "$t"; }; yy'';
      "asdf" = ''[ -n "$TMUX" ] && [ -z "$NVIM" ] && { [ "$(tmux display-message -p '#I')" = "2" ] && { clear; tmux select-window -t 1; exit 1; } || { [ "$(tmux display-message -p '#I')" = "1" ] && [ "$(tmux display-message -p '#{pane_index}')" = "1" ] && { clear; tmux detach; exit 1; }; }; }; exit 0'';
      "yt_dlq" = "~/.config/LSD/yt_dlq.sh";

      # Other:
      # shortcuts:
      ":q" = "exit";
      "vi" = "nvim";
      "ff" = "fastfetch";
      "ani" = "ani-cli";
      "lg" = "lazygit";
      "p3" = "python3";
      "cc" = "clear";
      "lsf" = "/usr/bin/ls | fzf";
      "btop" = "btop --force-utf";
      "hnctl" = "hostnamectl";
      "mk" = ''function mk(){ vared -p "Path: " -c var; mkdir "$var"; }; mk'';

      # flags or replacement:
      "fzf" = "fzf --cycle --wrap --multi --reverse";
      "df" = "df -Ph";
      "cp" = "cp -i";
      "du" = "du -h";
    };

    initContent = ''
      # LSD
      bindkey -s '^[a' "rofi-tmux add^M"
      bindkey -s '^[A' "rofi-tmux add-template^M"
      bindkey -s '^[C' "rofi-tmux kill-all^M"

      # fzf
      bindkey -s '^[c' \
        "ndir=\`fzf --walker=dir,hidden --walker-root=/\` && cd \$ndir^M"

      # git
      bindkey -s '^g' "lazygit^M"

      # other
      bindkey -r "^A"
      bindkey -s '^[f' "yy^M"

      bindkey '^ ' autosuggest-accept
      bindkey "^a" beginning-of-line
      bindkey "^e" end-of-line
      bindkey "^h" backward-word
      bindkey "^l" forward-word

      bindkey "^[[1;3D" backward-word
      bindkey "^[[1;3C" forward-word

      eval "$(starship init zsh)"
    '';
  };
}
