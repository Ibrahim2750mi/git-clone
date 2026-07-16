# Git-RV Documentation

This project is a small RISC-V assembly version-control system. Each project directory keeps its own repository data inside `.gitrv`, so version history is local to that directory.

The current command set is:

- `init` initializes tracking for the current project
- `commit -m "<message>"` saves a new version
- `log` shows saved versions
- `diff [commit-number]` compares the current working tree against a saved state
- `checkout <commit-number>` restores a saved state

## 1. What Each Command Does

### `init`

Creates:

- `.gitrv/`
- `.gitrv/parent/`

It also copies the current project snapshot into `.gitrv/parent/`.

This gives the project its own independent version area.

### `commit -m "<message>"`

Creates a new numbered snapshot:

- `.gitrv/1`
- `.gitrv/2`
- `.gitrv/3`

and appends metadata to `.gitrv/config`.

Each log entry currently stores:

- the message
- the timestamp returned by the Linux `time` syscall
- the commit number indirectly through the line number in `.gitrv/config`

### `log`

Reads `.gitrv/config` and prints each line prefixed with its version number.

This is the current history-browsing command.

### `diff [commit-number]`

Compares the current working tree recursively.

Behavior:

- `diff` or `diff 0` compares against `.gitrv/parent/`
- `diff 1` compares against `.gitrv/1/`
- `diff 2` compares against `.gitrv/2/`

It reports:

- `new: <path>`
- `modified: <path>`
- `deleted: <path>`

### `checkout <commit-number>`

Restores the working tree from `.gitrv/<commit-number>`.

Current behavior is strong restore behavior:

- it cleans the current directory first
- it preserves `.gitrv`
- it copies the selected snapshot back into `.`

This means untracked working files are removed during checkout.

## 2. Requirement Coverage

### 1. Project Management

Covered now:

- creating a project repository with `init`
- keeping project history inside the project directory with `.gitrv`
- independent history per project directory

How it works:

- every folder you run `init` in becomes its own tracked project
- there is no global multi-project dashboard yet
- multiple projects are managed by having separate directories, each with its own `.gitrv`

### 2. Version Tracking

Covered now:

- saving versions with `commit -m "<message>"`
- storing the saved content as a full snapshot in `.gitrv/<n>`
- storing why it was saved via the commit message
- storing when it was saved via a timestamp in `.gitrv/config`

Current representation:

- file snapshot in `.gitrv/<commit-number>/`
- metadata line in `.gitrv/config`

### 3. History Exploration

Covered now:

- browsing version history with `log`
- inspecting older states indirectly with `diff <commit-number>`
- restoring older states with `checkout <commit-number>`


### 4. Version Comparison

Covered now:

- recursive comparison using `diff`
- compare current state to parent or to a specific commit
- reports `new`, `modified`, and `deleted`

Current comparison style:

- file-level comparison
- content equality is byte-by-byte
- recursive across subdirectories

To compare two different commits, commit your current, work checkout into one of the commits you want to compare and `diff` with the other.

### 5. Restore Functionality

Covered now:

- `checkout <commit-number>` reliably restores a saved snapshot

Status: covered, with an important note

Important behavior:

- checkout deletes the current working tree contents before copying the saved snapshot
- `.gitrv` is preserved
- this behaves more like a full project restore than Git’s safer selective checkout behavior

### 6. Search & Discovery

Covered now:

- `log` lets users discover versions in chronological order
- commit messages make entries human-readable
- commit numbers are stable lookup keys for `diff` and `checkout`

## 3. Repository Layout

The most important files are:

- `src/init.s` initializes `.gitrv` and seeds `.gitrv/parent`
- `src/commit.s` creates a numbered snapshot and writes metadata
- `src/log.s` prints commit history from `.gitrv/config`
- `src/diff.s` compares current state against parent or a selected commit
- `src/checkout.s` restores a selected snapshot
- `src/snapshot.s` contains the reusable recursive snapshot-copy logic
- `src/modules/string.s` contains helpers like `strcpy`, `strcat`, `strlen`, `strcmpr`, `itoa`
- `src/modules/file_handling.s` contains helpers like `readfile`, `appendfile`, `countlines`, `clean_directory`
- `src/modules/constants.s` contains syscall numbers, flags, and shared constants

## 4. Build Commands

Build from `src/` so the `.include "modules/constants.s"` paths resolve correctly.

### Build `init`

```bash
cd /home/hp/CLionProjects/git-clone/src
riscv64-linux-gnu-as -o /tmp/init.o init.s
riscv64-linux-gnu-as -o /tmp/snapshot.o snapshot.s
riscv64-linux-gnu-ld -o /tmp/init /tmp/init.o /tmp/snapshot.o
```

### Build `commit`

```bash
cd /home/hp/CLionProjects/git-clone/src
riscv64-linux-gnu-as -o /tmp/commit.o commit.s
riscv64-linux-gnu-as -o /tmp/snapshot.o snapshot.s
riscv64-linux-gnu-as -o /tmp/string.o modules/string.s
riscv64-linux-gnu-as -o /tmp/file_handling.o modules/file_handling.s
riscv64-linux-gnu-ld -o /tmp/commit /tmp/commit.o /tmp/snapshot.o /tmp/string.o /tmp/file_handling.o
```

### Build `log`

```bash
cd /home/hp/CLionProjects/git-clone/src
riscv64-linux-gnu-as -o /tmp/log.o log.s
riscv64-linux-gnu-as -o /tmp/string.o modules/string.s
riscv64-linux-gnu-as -o /tmp/file_handling.o modules/file_handling.s
riscv64-linux-gnu-ld -o /tmp/log /tmp/log.o /tmp/string.o /tmp/file_handling.o
```

### Build `diff`

```bash
cd /home/hp/CLionProjects/git-clone/src
riscv64-linux-gnu-as -o /tmp/diff.o diff.s
riscv64-linux-gnu-as -o /tmp/string.o modules/string.s
riscv64-linux-gnu-ld -o /tmp/diff /tmp/diff.o /tmp/string.o
```

### Build `checkout`

```bash
cd /home/hp/CLionProjects/git-clone/src
riscv64-linux-gnu-as -o /tmp/checkout.o checkout.s
riscv64-linux-gnu-as -o /tmp/snapshot.o snapshot.s
riscv64-linux-gnu-as -o /tmp/string.o modules/string.s
riscv64-linux-gnu-as -o /tmp/file_handling.o modules/file_handling.s
riscv64-linux-gnu-ld -o /tmp/checkout /tmp/checkout.o /tmp/snapshot.o /tmp/string.o /tmp/file_handling.o
```

## 5. Run Commands

Run the binaries with `qemu-riscv64` from inside the project you want to manage.

### Initialize a project

```bash
cd /path/to/project
qemu-riscv64 /tmp/init
```

### Save a version

```bash
cd /path/to/project
qemu-riscv64 /tmp/commit -m "initial version"
```

### Show history

```bash
cd /path/to/project
qemu-riscv64 /tmp/log
```

### Compare against parent

```bash
cd /path/to/project
qemu-riscv64 /tmp/diff
```

or

```bash
cd /path/to/project
qemu-riscv64 /tmp/diff 0
```

### Compare against a specific commit

```bash
cd /path/to/project
qemu-riscv64 /tmp/diff 1
```

### Restore a commit

```bash
cd /path/to/project
qemu-riscv64 /tmp/checkout 1
```

## 6. Recommended Workflow

Use the system effectively in this order:

1. Run `init` once at the root of a project.
2. Make changes in the project.
3. Save checkpoints with `commit -m "<reason>"`.
4. Use `log` to find the version number you want.
5. Use `diff <n>` to inspect how the current tree differs from that version.
6. Use `checkout <n>` only when you really want to restore that full snapshot.

Practical advice:

- do not run `checkout` casually because it removes current working files before restore
- keep commit messages meaningful, because `log` is your main discovery tool right now
- run commands from the project root so paths are interpreted correctly
- treat commit number `0` as the original parent snapshot created during `init`

## 7. Current Limitations

These are the main gaps today:

- no branch support
- no line-by-line textual diff
- no search by keyword/date/file yet
- no selective restore of one file
- `checkout` is destructive to non-repository files in the working tree
