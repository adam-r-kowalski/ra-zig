#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/mman.h>

#define loop while (1)

typedef char u8;
typedef uint64_t u64;
typedef int64_t i64;
typedef int32_t i32;
typedef float f32;

u8* readtill(u8* buffer, u8 c, u64 times) {
    loop if (*buffer++ == c && --times == 0) return buffer;
}

typedef struct {
    u8* ptr;
    u64 len;
} Blk;

Blk readfile(u8* filename) {
    Blk blk;
    i64 fd = open(filename, O_RDONLY);
    blk.len = lseek(fd, 0, SEEK_END);
    lseek(fd, 0, SEEK_SET);
    i32 prot = PROT_READ | PROT_WRITE;
    i32 flags = MAP_PRIVATE | MAP_ANONYMOUS;
    blk.ptr = mmap(NULL, blk.len, prot, flags, -1, 0);
    read(fd, blk.ptr, blk.len);
    close(fd);
    return blk;
}

f32 classify(u8* buffer) {
    f32 correct = 0;
    f32 total = 0;
    buffer = readtill(buffer, '\n', 1);
    loop {
	total += 1;
	buffer = readtill(buffer, ',', 1);
	u8 alive = *buffer == '1';
	buffer = readtill(buffer, ',', 4);
	u8 male = *buffer == 'm';
	buffer = readtill(buffer, '\n', 1);
	correct += (male && !alive) || (!male && alive);
	if (*buffer == '\0') break;
    }
    return correct / total;
}

i32 main() {
    Blk blk = readfile("train.csv");
    f32 accuracy = classify(blk.ptr);
    printf("accuracy %f\n", accuracy);
    munmap(blk.ptr, blk.len);
}
