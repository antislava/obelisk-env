## Usage

Clone this repo with submodules:

```
git clone https://github.com/antislava/obelisk-env new-obelisk-project --recurse-submodules
```
or download submodule afterwards `git submodule update --init --recursive`.

Optionally create a separate branch for the new project with `git checkout -b new-obelisk-project` if planning to use it as a starting point/template for other projects.

Update obelisk repo information and install obelisk:

```bash
make nix/obelisk.git.json -B
make nix/obelisk.nix -B
make ob-install-global
```

Initialise the obelisk skeleton and patch [default.nix](./default.nix) to use the initalised obelisk repo in the [nix directory](./nix)

```bash
ob init --force
make patches
```

Test skeleton with `ob run` and `ob repl`.

Enter the respective nix shells

```bash
make shells-ghc
make shells-ghcjs
```

### Tag generation

```
make haskdeps
make tags
```
