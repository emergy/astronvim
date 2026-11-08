# Подключается из системного nix-on-droid.nix после первичной генерации файла.
{ config, lib, ... }:
{
  environment.etc."resolv.conf" = {
    text = lib.mkForce null;
    source = lib.mkForce "${config.user.home}/.local/state/android-dns/resolv.conf";
  };
}
