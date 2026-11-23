import sys
from itertools import zip_longest


def compare_traces(iss_file, rtl_file):
    with open(iss_file, "r") as f:
        iss_lines = f.readlines()

    with open(rtl_file, "r") as f:
        rtl_lines = f.readlines()

    print(f"ISS trace: {len(iss_lines)} lines")
    print(f"RTL trace: {len(rtl_lines)} lines")
    print("-" * 60)

    mismatch_count = 0

    for line_num, (iss_line, rtl_line) in enumerate(
        zip_longest(iss_lines, rtl_lines, fillvalue=None), start=1
    ):

        if iss_line != rtl_line:
            mismatch_count += 1
            print(f"\nMismatch at line {line_num}:")

            if iss_line is None:
                print("ISS: <END OF FILE>")
            else:
                print(f"ISS: {iss_line.rstrip()!r}")

            if rtl_line is None:
                print("RTL: <END OF FILE>")
            else:
                print(f"RTL: {rtl_line.rstrip()!r}")

            # Stop after the first mismatch.
            break

    print("\n" + "-" * 60)

    if mismatch_count == 0:
        print("PASS: ISS and RTL traces match exactly.")
        return True
    else:
        print("FAIL: ISS and RTL traces do not match.")
        return False


if __name__ == "__main__":
    iss_file = sys.argv[1] if len(sys.argv) > 1 else "iss_trace.txt"
    rtl_file = sys.argv[2] if len(sys.argv) > 2 else "rtl_trace.txt"

    compare_traces(iss_file, rtl_file)


