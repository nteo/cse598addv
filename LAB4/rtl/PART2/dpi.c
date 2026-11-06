#include <stdio.h>
#include <stdbool.h>

#define DEPTH 8

int fifo[DEPTH];

int write_ptr = 0;
int read_ptr = 0;
int count = 0;

void push(int data) {
    if (count < DEPTH) {
        fifo[write_ptr] = data;
        write_ptr = (write_ptr + 1) % DEPTH;
        count++;
    }
}

int pop() {
    int data;
    if (count > 0) {
        data = fifo[read_ptr];
        read_ptr = (read_ptr + 1) % DEPTH;
        count--;
    }
    else {
        data = NULL;
    }
    return data;
}

bool is_full() {
    return count == DEPTH;
}

bool is_empty() {
    return count == 0;
}