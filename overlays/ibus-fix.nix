final: prev: {
  ibus = prev.ibus.overrideAttrs (oldAttrs: {
    makeFlags = (oldAttrs.makeFlags or []) ++ [ "-j1" ];
  });
}
