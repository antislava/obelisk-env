{ compiler ? "ghc"
, targets ? ps: with ps; [ common frontend backend ]
}:
let
  main                  = import ../. {};
  doUnpackSource        = import ../nix-utils/doUnpackSource.nix;
  extractHaskellSources = import ../nix-utils/extractHaskellSources.nix;
  nixpkgs = main.reflex.nixpkgs;
  targetPaths = targets main.ghc;
  targetNames = map (p: p.pname) targetPaths;
  # targetNixPaths = map (p: p + "/default.nix") targetPaths;
  ghcWithDeps = main.${compiler}.ghcWithPackages targets;
  srcPaths = with builtins;
    if   hasAttr "paths" ghcWithDeps
    then filter (hasAttr "pname") ghcWithDeps.paths
    else [];
  srcPathsEx = with builtins;
    filter (p: !(elem p.pname targetNames)) srcPaths;
  packageSources =
    map (p: {src = "${doUnpackSource p nixpkgs}"; nm = p.name;}) srcPathsEx;

in {
  # inherit main;
  # inherit srcPaths;
  # inherit srcPathsEx;
  # inherit packageSources;
  sources = extractHaskellSources nixpkgs packageSources;
}
