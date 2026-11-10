CC = gcc
CLANG ?= clang
BPFTOOL ?= bpftool
CFLAGS = -Wall -Wextra -O2 -std=c11 -Iinclude
BPF_ARCH ?= x86
BPF_INCLUDE ?= /usr/include/$(shell uname -m)-linux-gnu
LIBBPF_LIBS := $(shell pkg-config --libs libbpf 2>/dev/null || echo '-lbpf -lelf -lz')

TARGET = build/processwatch
SOURCES = src/main.c src/process.c src/security.c

.PHONY: all ebpf test clean
all: $(TARGET)

build:
	mkdir -p build

$(TARGET): $(SOURCES) include/process.h include/security.h | build
	$(CC) $(CFLAGS) $(SOURCES) -o $@

ebpf: build/process_exec.bpf.o build/processwatch-loader

ebpf/vmlinux.h:
	@test -r /sys/kernel/btf/vmlinux || (echo "Kernel BTF missing: /sys/kernel/btf/vmlinux" >&2; exit 1)
	$(BPFTOOL) btf dump file /sys/kernel/btf/vmlinux format c > $@.tmp
	mv $@.tmp $@

build/process_exec.bpf.o: ebpf/process_exec.bpf.c ebpf/process_event.h ebpf/vmlinux.h | build
	$(CLANG) -O2 -g -target bpf -D__TARGET_ARCH_$(BPF_ARCH) -Iebpf -I$(BPF_INCLUDE) -c $< -o $@

build/processwatch-loader: ebpf/loader.c ebpf/process_event.h | build
	$(CC) -O2 -Wall -Wextra -Iebpf $< -o $@ $(LIBBPF_LIBS)

build/test_process: tests/test_process.c src/process.c src/security.c include/process.h include/security.h | build
	$(CC) $(CFLAGS) tests/test_process.c src/process.c src/security.c -o $@

test: build/test_process
	./build/test_process
	bash -n tests/workload.sh scripts/benchmark.sh

clean:
	rm -rf build
	rm -f ebpf/vmlinux.h ebpf/vmlinux.h.tmp
