#include <stdio.h>
#include <stdlib.h>

#define loop while (1)

typedef char u8;
typedef uint64_t u64;
typedef int64_t i64;
typedef int32_t i32;
typedef float f32;

u8* readtill(u8* buffer, u8 c, u64 times) {
    loop if (*buffer++ == c && --times == 0) return buffer;
}

u8* readfile(u8* filename) {
    FILE *fp = fopen(filename, "r");
    fseek(fp, 0, SEEK_END);
    u64 size = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    u8 *buffer = malloc(size + 1);
    fread(buffer, 1, size, fp);
    fclose(fp);
    return buffer;
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

int main() {
    u8 *buffer = readfile("train.csv");
    f32 accuracy = classify(buffer);
    printf("accuracy %f\n", accuracy);
    free(buffer);
}
