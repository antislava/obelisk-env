FAST_TAGS_VER := $(shell fast-tags --version 2>/dev/null)

DIR = .
NIX-DIR = ./nix
NIXPKGS = $(NIX-DIR)/nixpkgs.git.json
OBELISK = $(NIX-DIR)/obelisk.git.json
OBELISK-NIX = $(NIX-DIR)/obelisk.nix
HDEPS   = ./.haskdeps
# TARGETS = "ps: [ ]"

INIT-GHC   = "ghc-pkg list | head -1 | xargs | xargs -I {} ln -sf -T {} $(HDEPS)/package.conf.d.ghc; ls -1 $(HDEPS)/package.conf.d.ghc | sort > $(HDEPS)/package.conf.d.ghc.txt; ghc-pkg list --simple-output | tr ' ' '\n' | sort > $(HDEPS)/ghc-all.txt"
INIT-GHCJS = "ghcjs-pkg list | head -1 | xargs | xargs -I {} ln -sf {} $(HDEPS)/package.conf.d.ghcjs; ls -1 $(HDEPS)/package.conf.d.ghcjs | sort > $(HDEPS)/package.conf.d.ghcjs.txt; ghcjs-pkg list --simple-output | tr ' ' '\n' | sort > $(HDEPS)/ghcjs-all.txt"

INIT-GHC-RET   = $(INIT-GHC)"; return"
INIT-GHCJS-RET = $(INIT-GHC)"; return"

# DEFAULT
.PHONY : default
default:
	@echo "No default action. Use specific make flags instead!"


# NIX

# make -B nix/nixpkgs.git.json to force update
$(NIXPKGS) :
	# Switch between the original nixpkgs at github or a local mirror/fork:
	# nix-prefetch-git https://github.com/NixOS/nixpkgs > $(NIXPKGS)
	cd /r-cache/git/github.com/NixOS/nixpkgs && \
		git fetch
	nix-prefetch-git /r-cache/git/github.com/NixOS/nixpkgs > $(NIXPKGS)

# make -B nix/obelisk.git.json to force update
$(OBELISK) :
	# Switch between the original obelisk at github or a local mirror/fork:
	# nix-prefetch-git https://github.com/obsidiansystems/obelisk > $(OBELISK)
	cd /r-cache/git/github.com/obsidiansystems/obelisk && \
		git fetch
	mkdir -p $(NIX-DIR)
	nix-prefetch-git /r-cache/git/github.com/obsidiansystems/obelisk > $(OBELISK)

$(OBELISK-NIX) :
	mkdir -p $(NIX-DIR)
	echo -e "with builtins.fromJSON (builtins.readFile ./obelisk.git.json);\nbuiltins.fetchGit { inherit url rev; }" > $(OBELISK-NIX)


# OBELISK (and other tools) SHELL

.PHONY : ob-install-global
ob-install-global : $(OBELISK) $(OBELISK-NIX)
	nix-env -f "<nixpkgs>" -i -E "f: (import (import ./nix/obelisk.nix) { }).command"

.PHONY : ob-install-local
ob-install-local : $(OBELISK) $(OBELISK-NIX)
	nix-build -E "(import (import ./nix/obelisk.nix) { }).command" -o ./.ob

.PHONY : shell-tools
shell-tools : $(OBELISK) $(OBELISK-NIX)
	# nix-shell -p "(import (import ./nix/obelisk.nix) { }).command" "haskellPackages.ghcWithPackages (ps: [ ps.fast-tags ])"
	nix-shell -p "haskellPackages.ghcWithPackages (ps: [ ps.fast-tags ])"


# Small changes in default.nix...

patches :
	patch default.nix -i default.nix.patch


# NIX-SHELL

# Not used but keeping it for the future
# assert-ghc-shell := $(shell if [ -z $(NIX_GHC) ]; then echo "GHC is not installed. Enter nix-shell script (e.g. make shell)"; exit 1; fi;)

shells-init :
	nix-shell -A shells.ghc   --run $(INIT-GHC)
	nix-shell -A shells.ghcjs --run $(INIT-GHCJS)

.PHONY : shell-ghc
# shell-ghc : nix-shell-check
shell-ghc :
ifndef NIX_GHC
	# @touch nix-shell-check
	mkdir -p $(HDEPS)
	nix-shell -A shells.ghc --command $(INIT-GHC-RET)
else
	$(error Already in GHC shell!)
endif

.PHONY : shell-ghcjs
# shell-ghc : nix-shell-check
shell-ghcjs :
ifndef NIX_GHCJS
	# @touch nix-shell-check
	mkdir -p $(HDEPS)
	nix-shell -A shells.ghcjs --command $(INIT-GHCJS-RET)
else
	$(error Already in GHCJS shell!)
endif

# # .PHONY : nix-shell-check
# # nix-shell-check : project.nix $(PKG-NIX) nix/* nix-deps/*
# nix-shell-check : project.nix nix/* nix-deps/*
# 	@echo "Some nix shell dependencies changed!"


# TAGS GENERATION

.FORCE:

# hasktags seems to have problems because of lazy IO. Switched to fast-tags
tags : .FORCE haskdeps $(HDEPS)/core
ifdef FAST_TAGS_VER
	mkdir -p $(HDEPS)/all
	mkdir -p $(HDEPS)/ghc
	mkdir -p $(HDEPS)/ghcjs
	cp -d $(HDEPS)/ghc/*   $(HDEPS)/all
	cp -d $(HDEPS)/ghcjs/* $(HDEPS)/all
	fast-tags -RL . $(HDEPS)/all -o tags
else
	$(error fast-tags not installed! Are you in the right shell?)
endif

# NOTE:
# Currently generating two directories for ghc and ghcjs, which greatly overlap, resulting in many redundancies in tags file!
haskdeps :
	nix-build nix/sources.nix -A sources -o $(HDEPS)/ghc --argstr compiler "ghc" --arg targets "ps: [ ps.common ps.frontend ps.backend ]"
	nix-build nix/sources.nix -A sources -o $(HDEPS)/ghcjs --argstr compiler "ghcjs" --arg targets "ps: [ ps.common ps.frontend ]"
# make doesn't like <(...) too much...
	ls -1 $(HDEPS)/ghc   > $(HDEPS)/ghc.txt
	ls -1 $(HDEPS)/ghcjs > $(HDEPS)/ghcjs.txt
	comm -2 -3 $(HDEPS)/ghc-all.txt   $(HDEPS)/ghc.txt   > $(HDEPS)/ghc-core.txt
	comm -2 -3 $(HDEPS)/ghcjs-all.txt $(HDEPS)/ghcjs.txt > $(HDEPS)/ghcjs-core.txt

$(HDEPS)/core :
	rm -rf $(HDEPS)/core
	mkdir  $(HDEPS)/core
	cat $(HDEPS)/ghc-core.txt $(HDEPS)/ghcjs-core.txt | sort | uniq | xargs -I P sh -c 'cabal get P -d /cabal-cache; ln -s /cabal-cache/P $(HDEPS)/core'

# $(HDEPS)/ghc-core :
# ifdef NIX_GHC
# 	rm -rf $(HDEPS)/ghc-core
# 	mkdir  $(HDEPS)/ghc-core
# 	cat $(HDEPS)/ghc-core.txt | xargs -I P sh -c 'cabal get P -d /cabal-cache; ln -s /cabal-cache/P $(HDEPS)/ghc-core'
# else
# 	$(error Not in GHC shell!)
# endif

# $(HDEPS)/ghcjs-core :
# ifdef NIX_GHCJS
# 	rm -rf $(HDEPS)/ghcjs-core
# 	mkdir  $(HDEPS)/ghcjs-core
# 	cat $(HDEPS)/ghcjs-core.txt | xargs -I P sh -c 'cabal get P -d /cabal-cache; ln -s /cabal-cache/P $(HDEPS)/ghcjs-core'
# else
# 	$(error Not in GHCJS shell!)
# endif


# CLEANING

.PHONY: clean-all
clean-all : clean-tmp clean-tags clean-build

.PHONY: clean-build
clean-build :
	cabal clean
	cabal new-clean
	rm -r dist

.PHONY: clean-tags
clean-tags :
	rm -f  tags
	rm -rf $(HDEPS)

.PHONY: clean-tmp
clean-tmp :
	rm -f  .ghc.environment.*

