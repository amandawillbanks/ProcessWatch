# VCL Linux Environment Verification

**Do not assume Xinu QEMU guest = Linux host.** ProcessWatch uses Linux interfaces and should be run on an authorized Linux host. Verify the project target with the instructor.

## Safe read-only checks
Run these in the VCL Linux terminal:
```bash
pwd
uname -a
cat /etc/os-release
command -v gcc
command -v make
command -v clang
command -v bpftool
pkg-config --modversion libbpf 2>/dev/null || true
ls -ld /proc /sys/kernel/btf/vmlinux 2>&1
id
```

Record results privately in your notes (do not commit sensitive system identifiers). The existence of tools or BTF is not proof of permission to load eBPF programs.

## Persistence and Git
Confirm a persistent workspace before cloning; VCL home directories may be ephemeral depending on configuration. Previous coursework used a persistent `/mnt/ncsudrive/` location, but verify it exists and is writable on this session.

```bash
git clone https://github.com/amandawillbanks/ProcessWatch.git
cd ProcessWatch
git status
```

If already cloned, use `git pull --ff-only` after confirming there are no uncommitted local changes.

## eBPF feasibility checklist
- [ ] Linux kernel version supports chosen tracepoint and libbpf approach
- [ ] Kernel BTF or alternative headers available for chosen build strategy
- [ ] clang/LLVM and libbpf headers available
- [ ] Required permissions/capabilities available under VCL policy
- [ ] Instructor permits loading eBPF on the managed host
- [ ] A minimal test program can load and attach successfully

**Do not attempt privilege escalation or bypass VCL restrictions.** If eBPF cannot be used, ask the instructor about acceptable alternatives.

## Build status
The Makefile is currently a placeholder and does not build an executable. Actual commands will be added after the implementation and toolchain checks.
