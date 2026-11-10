{
  description = "Рабочее окружение AstroNvim для Nix-версии Termux Launcher";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c56a87d8e41ce69bd2af57eb35dcc117a9dfca33";
  inputs.nix-on-droid-src = {
    url = "github:PickleHik3/nix-on-droid/67e57bd287c0dff63be25ce9ca8f0761afaccc11";
    flake = false;
  };
  outputs = { self, nixpkgs, nix-on-droid-src }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      procpsAndroid = pkgs.callPackage ./procps-android.nix {};
      termuxAm = pkgs.callPackage (nix-on-droid-src + "/pkgs/android-integration/termux-am.nix") {};
      termuxTools = pkgs.callPackage (nix-on-droid-src + "/pkgs/android-integration/termux-tools.nix") {
        termux-am = termuxAm;
      };
      startSshd = pkgs.writeShellScriptBin "start-sshd" (builtins.readFile ./start-sshd);
      nterm = pkgs.writeShellScriptBin "nterm" ''
        nterm_config="''${XDG_CONFIG_HOME:-$HOME/.config}"
        nterm_root="''${NTERM_CONFIG_DIR:-$nterm_config/nvim}"
        exec "$nterm_root/scripts/nterm" "$@"
      '';
      setupStorage = pkgs.writeShellScriptBin "setup-storage" (builtins.readFile ./setup-storage.sh);
      androidDns = pkgs.writeScriptBin "android-dns" (
        "#!${pkgs.python3}/bin/python3\n" + builtins.readFile ./dns-bridge/android_dns.py
      );
      invi = pkgs.buildGoModule {
        pname = "invi";
        version = "git-12ac4ed";
        # Снимок исходников локального репозитория invi, без пользовательских конфигов.
        src = builtins.path {
          path = ./invi-src;
          name = "invi-source";
          sha256 = "sha256-qqb/pDehx/F/NwAHV7vA5eVU9U09YAUVCN7RWFn2zEw=";
        };
        vendorHash = "sha256-1eQLPPD9DyWtZ7hls2qD73ZzwEukQfXhQKyvp/iAOHA=";
        subPackages = [ "cmd/invi" ];
        env.CGO_ENABLED = "0";
        doCheck = false;
        ldflags = [ "-s" "-w" "-X main.version=12ac4ed" ];
      };
      codex = pkgs.stdenvNoCC.mkDerivation {
        pname = "codex-cli";
        version = "0.167.0";
        src = pkgs.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v0.167.0/codex-aarch64-unknown-linux-musl.tar.gz";
          hash = "sha256-hDSJrLTUsQeXRcNrA8WWO4h7gxVa8gj9U1hOM+6OsoE=";
        };
        sourceRoot = ".";
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          install -Dm755 codex-aarch64-unknown-linux-musl "$out/bin/codex"
          runHook postInstall
        '';
      };
    in {
      packages.${system} = {
        procps-android = procpsAndroid;
        inherit invi nterm;
        default = pkgs.buildEnv {
          name = "nix-launcher-workstation";
          paths = with pkgs; [
            (neovim.override { vimAlias = true; viAlias = true; })
            git openssh curl wget coreutils findutils gnugrep gnused gawk
            gnutar gzip bzip2 xz unzip zip file procpsAndroid util-linux which
            gcc gnumake pkg-config tree-sitter
            ripgrep fd fzf jq yq-go less bat tree lazygit bash-completion
            python3 ansible ansible-lint nodejs
            lua-language-server yaml-language-server ansible-language-server
            basedpyright bash-language-server dockerfile-language-server
            vscode-langservers-extracted helm-ls marksman stylua shfmt
            tmux bubblewrap
            kubectl kubernetes-helm k9s argocd rclone vifm mc gh terraform-ls shellcheck
            codex invi nterm startSshd setupStorage androidDns
            termuxAm termuxTools.open termuxTools.open_url termuxTools.xdg_open
            termuxTools.reload_settings termuxTools.setup_storage
            termuxTools.wake_lock termuxTools.wake_unlock
          ];
        };
      };
    };
}
