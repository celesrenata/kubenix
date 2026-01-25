final: prev: {
  nodejs_24 = prev.nodejs_24.overrideAttrs (oldAttrs: {
    doCheck = false;
  });
}
