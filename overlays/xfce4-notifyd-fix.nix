final: prev: {
  xfce4-notifyd = prev.xfce4-notifyd.overrideAttrs (oldAttrs: {
    enableParallelBuilding = false;
  });
}
