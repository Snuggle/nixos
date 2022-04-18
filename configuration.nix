# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
# pkgs.lib.mkForce

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      (import "${builtins.fetchTarball https://github.com/rycee/home-manager/archive/master.tar.gz}/nixos")
    ];

  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    extraModulePackages = [
      config.boot.kernelPackages.v4l2loopback
    ];

    # Register a v4l2loopback device at boot
    kernelModules = [
      "v4l2loopback"
    ];
  };

  environment.gnome.excludePackages = [ pkgs.dejavu_fonts ];
  security.rtkit.enable = true;
  # Enable sound.
  hardware.pulseaudio.enable = false;

  systemd = {
    services = {
      # Don't take ~30s to boot
      systemd-udev-settle.enable = false;
      NetworkManager-wait-online.enable = false;

      # Set Papirus Folder Colours
      papirus-folders = {
        description = "papirus-folders";
        path = [ pkgs.bash pkgs.stdenv pkgs.coreutils pkgs.gawk pkgs.getent pkgs.gtk3 ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.fetchFromGitHub
              {
                owner = "PapirusDevelopmentTeam";
                repo = "papirus-folders";
                rev = "86c63fdd21182e5cc8444ba488042559951ca106";
                sha256 = "sha256-ZZMEZCWO+qW76eqa+TgxWGVz69VkSCPcttLoCrH7ppY=";
              } + "/papirus-folders"} -t ${pkgs.papirus-icon-theme}/share/icons/Papirus --verbose --color yaru";
        };
        wantedBy = [ "default.target" ];
      };
    };

    user.services = {
      nextcloud-config-update = {
        enable = true;
        description = "Update Nextcloud Config";
        path = [ pkgs.bash pkgs.stdenv pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.coreutils}/bin/cp --no-clobber ${config/Nextcloud/nextcloud.cfg} ${config.users.users.snuggle.home}/.config/Nextcloud/nextcloud.cfg";
          ExecStartPost="${pkgs.coreutils}/bin/chmod +w ${config.users.users.snuggle.home}/.config/Nextcloud/nextcloud.cfg";
        };
        wantedBy = [ "default.target" ];
      };

      # My own public GPG key must be imported otherwise you'll get the below error when trying to sign a git commit:
      # error: gpg failed to sign the data fatal: failed to write commit object
      gpg-import-keys = {
        enable = true;
        description = "Automatically import my public GPG keys";
        unitConfig = {
          After = [ "gpg-agent.socket" ];
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.gnupg}/bin/gpg --import ${
            builtins.fetchurl { 
              url = "https://github.com/${config.users.users.snuggle.name}.gpg"; 
              sha256 = "06ncqgs3fn5bp6w8qdzd33a22ckym9ndpz7q7hqxf4wg2rjri77r"; 
            }}'";
        };

        wantedBy = [ "default.target" ];
      };
    };
  };

  
  # Set your time zone.
  time.timeZone = "Europe/London";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.

  networking = {
    hostName = "plum"; # Define your hostname.
    useDHCP = false;
    interfaces.enp38s0.useDHCP = true;
    interfaces.wlp37s0.useDHCP = true;

    extraHosts =
      ''
        10.0.1.6 hug
      '';
    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    firewall = {
      allowedTCPPorts = [ 7777 ];
      allowedUDPPorts = [ 51820 ];
    };

    wireguard = {
      enable = false; # Poor performance, disabling for now.
      interfaces = {
        wg0 = {
          ips = [ "10.100.0.2/32" ];
          listenPort = 51820;
          privateKeyFile = "${config.users.users.snuggle.home}/.wireguard/private";

          peers = [
            # For a client configuration, one peer entry for the server will suffice.

            {
              # Public key of the server (not a file path).
              publicKey = "2Y/T27X+ND1xUT3lfXQ0YpCjTocvMxn2c1Yv9eHG8kQ=";

              # Forward all the traffic via VPN.
              allowedIPs = [ "0.0.0.0/0" ];
              # Or forward only particular subnets
              #allowedIPs = [ "10.100.0.1" "91.108.12.0/22" ];

              # Set this to the server IP and port.
              endpoint = "home.snugg.ie:51820"; # ToDo: route to endpoint not automatically configured https://wiki.archlinux.org/index.php/WireGuard#Loop_routing https://discourse.nixos.org/t/solved-minimal-firewall-setup-for-wireguard-client/7577

              # Send keepalives every 25 seconds. Important to keep NAT tables alive.
              persistentKeepalive = 25;

              # Update DNS of endpoint
              dynamicEndpointRefreshSeconds = 30;
            }
          ];
        };
      };
    };
  };
	
  nixpkgs.config = { 
    allowUnfree = true;
    permittedInsecurePackages = [
        "electron-13.6.9"
        "electron-12.2.3"
    ];
  };  

  services = {
    # Enable the X11 windowing system.
    xserver.enable = true;

    # Enable the GNOME 3 Desktop Environment.
    xserver.displayManager.gdm.enable = true;
    xserver.desktopManager.gnome.enable = true;

      # List services that you want to enable:

    # Enable the OpenSSH daemon.
    openssh.enable = true;
    openssh.passwordAuthentication = false;
    openssh.permitRootLogin = "yes";
    openssh.kbdInteractiveAuthentication = false;
    openssh.extraConfig = ''
      PubkeyAcceptedAlgorithms +ssh-rsa
      HostkeyAlgorithms +ssh-rsa
    '';

    #services.dbus.packages = with pkgs; [ gnome3.dconf ];
    

    # Configure keymap in X11
    # services.xserver.layout = "us";
    # services.xserver.xkbOptions = "eurosign:e";

    # Enable CUPS to print documents.
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # If you want to use JACK applications, uncomment this
      #jack.enable = true;

      # use the example session manager (no others are packaged yet so this is enabled by default,
      # no need to redefine it in your config for now)
      #media-session.enable = true;
    };

    pcscd.enable = true;
    udev.packages = with pkgs; [ pkgs.yubikey-personalization ];
  };

  system = {
    autoUpgrade.enable = true;

    activationScripts.setavatar.text = ''
      cp ${(builtins.fetchurl { 
        url = "https://github.com/Snuggle.png"; 
        sha256 = "0gyhr691jlyhdm6ha6jq67fal7appbk4mj2jp9bqh6sy5fflcj37"; 
      })} "/var/lib/AccountsService/users/snuggle"
    '';

    # Setup symlinks for NAS-based home directory
    userActivationScripts.linktosharedfolder.text = ''
      for location in \
        Desktop \
        Documents \
        Downloads \
        Games \
        Pictures \
        Public \
        Templates \
        Temporary \
        Videos \
        Music 
      do
        if [[ -d "${config.users.users.snuggle.home}/$location" ]]; then
          find "${config.users.users.snuggle.home}/$location" -type d -empty -exec rm --dir --verbose {} \;
        fi
        if [[ -d "${config.users.users.snuggle.home}/$location" ]]; then
          continue
        fi
        if [[ ! -L "${config.users.users.snuggle.home}/$location" ]]; then
          ln --symbolic --no-target-directory --verbose "$(findmnt /dev/disk/by-label/Games --noheadings --first-only --output TARGET)/Homesweet/$location/" "${config.users.users.snuggle.home}/$location"
        fi
      done
    '';
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.snuggle = {
    isNormalUser = true;
    description = "Evie Snuggle";
    createHome = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "libvirtd" "scanner" "lp" ]; # Enable ‘sudo’ for the user.

    openssh.authorizedKeys.keyFiles = [ (builtins.fetchurl { 
      url = "https://github.com/${config.users.users.snuggle.name}.keys"; 
      sha256 = "07fc06a9b436021592933be6c597ef56765f733b755720e72fa9190da35a26b4"; 
    }) ];
  };

  environment.systemPackages = with pkgs; [
    ### (Installed System Packages) ###

    # Applications
    _1password-gui
    # davinci-resolve # https://github.com/NixOS/nixpkgs/issues/94032
    discord
    firefox
    gparted
    inkscape
    kdenlive krita
    libreoffice
    nextcloud-client
    obs-studio obsidian
    spotify
    slack
    tdesktop teams transmission-gtk transmission-remote-gtk
    vivaldi vivaldi-ffmpeg-codecs vscode
    zoom-us

    # Development, Git or Libraries
    docker
    ffmpeg
    git gnupg
    jekyll
    ruby
    yubikey-personalization
    tailscale

    # GNOME Extensions
    gnomeExtensions.appindicator
    gnomeExtensions.burn-my-windows
    gnomeExtensions.gsconnect
    gnomeExtensions.mpris-indicator-button
    gnomeExtensions.night-theme-switcher

    # System Utilities
    brlaser
    dconf dconf2nix
    etcher
    glances gnome.dconf-editor gnome.gnome-software
    linuxKernel.kernels.linux_zen
    ntfs3g nv-codec-headers
    obinskit
    pavucontrol
    refind
    tmux
    virt-manager vlc
    wireguard-tools
    
    
    # Terminal Tools
    #alacritty
    bat bind
    exa
    fish
    kitty
    micro mosh
    neofetch
    optipng
    starship
    vim
    wget
    xclip

    # Theming
    arc-theme
    breeze-gtk
    gnome3.gnome-tweaks
    papirus-icon-theme
    yaru-theme

    # Un-GNU Coreutils, Replace GNU Coreutils with Busybox/Toybox
    (pkgs.hiPrio unixtools.fsck)
    # Required for NixOS with busybox otherwise "systemd-fsck[4070]: fsck.vfat: invalid option -- 'M'" error.
    # This ensures that `ls -l $(which fsck)` is pointing to the 'util-linux/bin/fsck' rather than 'busybox/bin/fsck'.
    # Failing to do this causes systemd to fail booting, dropping into emergency mode, on FAT32 /boot EFI partitions.
    busybox
    (pkgs.hiPrio toybox)
    (pkgs.lowPrio coreutils)
    (coreutils.override { minimal = true; })
  ];

  fonts = {
    enableDefaultFonts = false;

    fonts = with pkgs; [
      # Serif Fonts
      roboto-slab

      # Sans-serif Fonts
      fontforge
      source-sans # Previously 'source-sans-pro'
      source-serif # Previously 'source-serif-pro'
      noto-fonts
      ubuntu_font_family

      # Mono Fonts
      source-code-pro
      fantasque-sans-mono

      # Emoji Fonts
      noto-fonts-emoji-blob-bin

      # Non-English Fonts
      noto-fonts-cjk

      (nerdfonts.override { fonts = [ "FantasqueSansMono" "SourceCodePro" ]; })
    ];

    fontconfig = {
      defaultFonts = {
        serif = [ "Source Serif 4" "Roboto Slab" "Ubuntu" ];
        sansSerif = [ "Source Sans 3" "Ubuntu" ];
        monospace = [ "Fantasque Sans Mono" "Source Code Pro" "Ubuntu Mono" ];
        emoji = [ "Blobmoji" ];
        
      };
    };
  };

  environment.sessionVariables.TERMINAL = [ "kitty" ];
  environment.sessionVariables.VISUAL = [ "micro" ];
  environment.sessionVariables.EDITOR = [ "micro" ];
  environment.sessionVariables.NIXOS_OZONE_WL = "true"; # Apply Wayland flags to Electron apps where necessary

  environment.shellInit = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent /bye
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
  '';

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs = {
    steam.enable = true;
    fish = {
      enable = true;
      promptInit = "starship init fish | source";
      shellInit = builtins.readFile ./config/fish/colours.fish;
      shellAbbrs = {
        cat = "bat";
        ls = "exa --icons";
        "exa --icons -l" = "exa --icons -lah";
        nano = "micro";
        ssh = "mosh";
      };
    };

    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  home-manager.users.snuggle = { 
    imports = [ ./config/dconf/dconf.nix ];

    #xdg.configFile."Nextcloud/nextcloud.cfg".source = config/Nextcloud/nextcloud.cfg;
    xdg.configFile."Nextcloud/sync-exclude.lst".source = config/Nextcloud/sync-exclude.lst;

    gtk = {
      enable = true;
      iconTheme.name = "Papirus";
      iconTheme.package = pkgs.papirus-icon-theme;
      theme.name = "Yaru-dark";
      theme.package = pkgs.yaru-theme;
      cursorTheme.package = pkgs.breeze-gtk;
      cursorTheme.name = "Breeze_Snow";
    };

    services = {
      nextcloud-client = {
        enable = true;
        startInBackground = true;
      };
    };

    programs = {
      firefox = {
        enable = true;

        profiles.default = {
          id = 0;
          name = "Default";
          isDefault = true;
          settings = {
            "browser.startup.homepage" = "https://storage.snugg.ie";
            "services.sync.username" = "^-^@snugg.ie";
            "services.sync.engine.passwords" = false;
            "font.name-list.emoji" = "Blobmoji";
            "font.default.x-western" = "sans-serif";
            "font.name.serif.x-western" = "Source Serif 4";
            "font.name.sans-serif.x-western" = "Source Sans 3";
            "font.name.monospace.x-western" = "Fantasque Sans Mono";
          };
        };

      extensions = 
        with pkgs.nur.repos.rycee.firefox-addons; [
          ublock-origin
          onepassword-password-manager
          firefox-color
          netflix-1080p
          refined-github
        ]; 
      };

      exa = {
        enableAliases = true;
      };

      git = {
        enable = true;
        userName  = "Snuggle";
        userEmail = "^-^@snugg.ie";
        signing.signByDefault = true;
        signing.key = "2D3825B49C6BCBE1AC337723877300954D1493E6";
        extraConfig = {
          merge.conflictstyle = "diff3";
        };
      };

      starship = {
          enable = true;
          enableFishIntegration = true;
          # Configuration written to ~/.config/starship.toml
          settings = {
            # add_newline = false;
      
            # package.disabled = true;
          };
      };

      gpg = {
        publicKeys = {
          snuggle = {
            source = [ (builtins.fetchurl { url = "https://github.com/${config.users.users.snuggle.name}.gpg"; sha256 = "06ncqgs3fn5bp6w8qdzd33a22ckym9ndpz7q7hqxf4wg2rjri77r"; }) ];
            # Doesn't seem to work, so I am using systemd instead.
          };
        };
      };

      bat = {
        enable = true;
        config.theme = "fairyfloss";
        themes = {
          fairyfloss = builtins.readFile (
            pkgs.fetchFromGitHub
                {
                owner = "sailorhg";
                repo = "fairyfloss";
                rev = "982e64a9e36160350125c0a82a7981dca6200150";
                sha256 = "1gpbkmy8axj8il0s85ifn2adm987nla0dbk2slwc5zyp6m9ak3qq";
                } + "/fairyfloss.tmTheme"
          );
        };
      };

      kitty = {
        enable = true;
        #theme = "fairyfloss";
        font = {
          name = "Fantasque Sans Mono";
          package = pkgs.fantasque-sans-mono;
          size = 14;
        };
        settings = {
          linux_display_server = "wayland";
          cursor_shape = "beam";
          background = "#5a5475";
          foreground = "#f8f8f0";
          cursor = "#ffb8d1";
          selection_foreground = "#ad5877";
          selection_background = "#ffb8d1";
          # Black
          color0 = "#464258";
          color8 = "#c19fd8";
          # Red
          color1 = "#ff857f";
          color9 = "#f44747";
          # Green
          color2 = "#ad5877";
          color10 = "#ffb8d1";
          # Yellow
          color3 = "#e6c000";
          color11 = "#ffea00";
          # Blue
          color4 = "#6c71c4";
          color12 = "#6796e6";
          # Magenta
          color5 = "#b267e6";
          color13 = "#c5a3ff";
          # Cyan
          color6 = "#afecad";
          color14 = "#b2ffdd";
          # White
          color7 = "#cccccc";
          color15 = "#f8f8f0";
        };
      };

      alacritty = {
        enable = false;
        settings = {
          cursor.style = {
            shape = "beam";
            blinking = "on";
          };
          font = {
            size = 14;
            normal = {
              family = "Fantasque Sans Mono Nerd Font";
            };
          };
          colors = {
            # Theme based upon: Fairyfloss (FairyShell for Terminal)
            # https://gist.github.com/crazy4pi314/c0874aef9a34e35f6ad07cc163662e51

            # Default colors
            primary = {
              background = "0x5a5475";
              foreground = "0xf8f8f0";
            };

            # Normal colors
            normal = {
              black = "0x464258";
              red = "0xff857f";
              green = "0xad5877";
              yellow = "0xe6c000";
              blue = "0x6c71c4";
              magenta = "0xb267e6";
              cyan = "0xafecad";
              white = "0xcccccc";
            };

            # Bright colors
            bright = {
              black = "0xc19fd8";
              red = "0xf44747";
              green = "0xffb8d1";
              yellow = "0xffea00";
              blue = "0x6796e6";
              magenta = "0xc5a3ff";
              cyan = "0xb2ffdd";
              white = "0xf8f8f0";
            };
          };
        };
      };
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?

}
