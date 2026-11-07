#include <stdio.h>
#include <stdbool.h>

#define DEPTH 16

int fifo[DEPTH];

int write_ptr;
int read_ptr;
int count;

void reset_fifo() {
    write_ptr = 0;
    read_ptr = 0;
    count = 0;
}

void push_fifo(int data) {
    if (count < DEPTH) {
        fifo[write_ptr] = data;
        write_ptr = (write_ptr + 1) % DEPTH;
        count++;
    }
}

int pop_fifo() {
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

bool is_fifo_full() {
    return count == DEPTH;
}

bool is_fifo_empty() {
    return count == 0;
}