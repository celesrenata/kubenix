final: prev: {
  arrow-cpp = prev.arrow-cpp.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
}
