final: prev: 
let
  pythonOverrides = pyfinal: pyprev: {
    uvloop = pyprev.uvloop.overrideAttrs (oldAttrs: {
      version = "0.22.1";
      src = final.fetchPypi {
        pname = "uvloop";
        version = "0.22.1";
        hash = "sha256-bIS640W5FHCCsXNx491dQndb3c6R+IVJkBf0YH/a858=";
      };
      disabledTests = (oldAttrs.disabledTests or []) ++ [
        "test_cancel_post_init"
      ];
    });
    anyio = pyprev.anyio.overrideAttrs (oldAttrs: {
      disabledTests = (oldAttrs.disabledTests or []) ++ [
        "test_handshake_fail"
        "test_single_thread"
      ];
    });
    paramiko = pyprev.paramiko.overrideAttrs (oldAttrs: {
      disabledTests = (oldAttrs.disabledTests or []) ++ [
        "test_sequence_numbers_reset_on_newkeys_when_strict"
      ];
    });
  };
in
{
  python3 = prev.python3.override {
    packageOverrides = pythonOverrides;
  };
  python312 = prev.python312.override {
    packageOverrides = pythonOverrides;
  };
  python3Packages = final.python3.pkgs;
  python312Packages = final.python312.pkgs;
}
