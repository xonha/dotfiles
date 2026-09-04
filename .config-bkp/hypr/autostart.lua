-- Autostart. Roda uma vez quando o Hyprland sobe (nao em reload),
-- que e a semantica do antigo exec-once.

hl.on("hyprland.start", function()
    -- Noctalia fornece o desktop shell e o agente Polkit.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("noctalia")
    hl.exec_cmd("xhost +SI:localuser:root")

    hl.exec_cmd(
        "sleep 4 && pactl set-default-source effect_output.rnnoise && pactl set-source-mute effect_output.rnnoise 1")
    hl.exec_cmd("valent --gapplication-service")

    hl.exec_cmd("sleep 2 && brave --profile-directory=Default")
end)

-- keyd remapeia esc/capslock: /etc/keyd/default.conf
-- sudo systemctl enable --now keyd
-- sudo systemctl disable --now keyd
