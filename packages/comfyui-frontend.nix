{ lib
, python312Packages
, fetchPypi
}:

python312Packages.buildPythonPackage rec {
  pname = "comfyui-frontend-package";
  version = "1.28.8";
  format = "wheel";

  src = fetchPypi {
    pname = "comfyui_frontend_package";  # PyPI uses underscores
    inherit version format;
    dist = "py3";
    python = "py3";
    abi = "none";
    platform = "any";
    sha256 = "sha256-vnbb+arbg2tnLmkWFFYpTWXzIE8VYuwfeK4SxpNHqOA=";
  };

  # No dependencies needed for frontend package
  propagatedBuildInputs = [ ];

  doCheck = false;

  meta = with lib; {
    description = "ComfyUI frontend package";
    homepage = "https://github.com/comfyanonymous/ComfyUI";
    license = licenses.gpl3Plus;
    platforms = platforms.all;
  };
}
