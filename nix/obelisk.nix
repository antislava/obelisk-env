with builtins.fromJSON (builtins.readFile ./obelisk.git.json);
builtins.fetchGit { inherit url rev; }
