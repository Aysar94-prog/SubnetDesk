# Local workspace layout

The local workspace separates the source checkout, installed tools, and release outputs:

```text
SubnetDesk-Helper/
  source/       # this Git repository
  tools/        # toolchain access and build/test caches; local only
  outputs/
    new/        # validated current releases; local only
    old/        # historical releases; local only
```

Run Git, Cargo and Flutter commands inside source/ (or source/flutter/). GitHub contains the contents of source/ at the repository root, so Cargo, Flutter and CI retain their existing relative paths. Build scripts, installer definitions, tests and required assets are source files and remain tracked. Installed tool binaries, dependency caches, installers and local planning state are excluded.

On the existing Windows workstation, local directory junctions preserve source/output, source/target, source/outputs and Flutter cache paths. The workspace output/ alias preserves older absolute candidate paths. The existing short path D:\SubnetDesk-Helper now resolves to source/. Junctions are workstation configuration, excluded from Git, and are not required for a fresh clone.

A fresh checkout can use ordinary ignored output/, target/ and outputs/ directories. Release publication follows AGENTS.md: validate first, publish under outputs/new/, archive previous versions under outputs/old/, and preserve artifact hashes.

Source repository: https://github.com/Aysar94-prog/SubnetDesk
Default branch: master (customized Helper, Deploy and Agent source).
The shared library is included directly under libs/hbb_common/. It is an ordinary source directory; no submodule or second repository is required.

Clone the source:

```sh
git clone https://github.com/Aysar94-prog/SubnetDesk.git source
```
