#include <stdio.h>

#define DEPTH 16

static int fifo[DEPTH];
static int write_ptr;
static int read_ptr;
static int count;

void reset_fifo(void) {
    write_ptr = 0;
    read_ptr  = 0;
    count     = 0;
}

// returns 0 on success, 1 if the model was already full (overflow)
int push_fifo(int data) {
    if (count >= DEPTH) return 1;
    fifo[write_ptr] = data;
    write_ptr = (write_ptr + 1) % DEPTH;
    count++;
    return 0;
}

// returns 0 on success, 1 if the model was empty (underflow).
int pop_fifo(int *data) {
    if (count <= 0) {
        *data = 0;
        return 1;
    }
    *data = fifo[read_ptr];
    read_ptr = (read_ptr + 1) % DEPTH;
    count--;
    return 0;
}

int fifo_count(void)    { return count; }
int is_fifo_full(void)  { return count == DEPTH; }
int is_fifo_empty(void) { return count == 0; }