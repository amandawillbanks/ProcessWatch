
CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c11 -Iinclude

TARGET = build/processwatch
SOURCES = src/main.c src/process.c src/security.c

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SOURCES) include/process.h include/security.h
	mkdir -p build
	$(CC) $(CFLAGS) $(SOURCES) -o $(TARGET)

clean:
	rm -rf build
