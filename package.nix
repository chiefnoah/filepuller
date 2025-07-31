{
  pkgs,
  lib,
  buildGoModule,
}:
buildGoModule (finalAttrs: {
  pname = "filepuller";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-PaF6zvqa97dCo2Mu6/agAYe1Yykp+BhXD7g7pVHAbwk=";
})
