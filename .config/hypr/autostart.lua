-- Autostart. Roda uma vez quando o Hyprland sobe (nao em reload),
-- que e a semantica do antigo exec-once.

hl.on("hyprland.start", function()
    -- hl.exec_cmd("~/.config/scripts/monitor.sh")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("~/.config/scripts/theme.sh")
    hl.exec_cmd("~/.config/scripts/waybar.sh")

    hl.exec_cmd(
        "sleep 4 && pactl set-default-source effect_output.rnnoise && pactl set-source-mute effect_output.rnnoise 1")
    hl.exec_cmd('hyprctl setcursor "Qogirr-Dark" 24')
    hl.exec_cmd('gsettings set org.gnome.desktop.interface cursor-theme "Qogirr-Dark"')
    hl.exec_cmd("/usr/lib/mate-polkit/polkit-mate-authentication-agent-1") -- mate-polkit
    hl.exec_cmd("valent --gapplication-service")
    hl.exec_cmd("mako")

    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user enable --now hyprpaper.service")
    hl.exec_cmd("systemctl --user enable --now hyprsunset.service")
    -- Atencao: hyprdynamicmonitors nao esta instalado e essa unit nao existe,
    -- esse comando falha silenciosamente (ja falhava no .conf).
    hl.exec_cmd("systemctl --user enable --now hyprdynamicmonitors.service")

    hl.exec_cmd("sleep 2 && brave --profile-directory=Default")
end)

-- keyd remapeia esc/capslock: /etc/keyd/default.conf
-- sudo systemctl enable --now keyd
-- sudo systemctl disable --now keyd
