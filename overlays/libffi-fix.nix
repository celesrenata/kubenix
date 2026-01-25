final: prev: {
  libffi = prev.libffi.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
}
