#!/usr/bin/env python3
"""Shuffle and check the best-idea judge rounds, so the model does neither in
its head.

  judge.py map 3 7 9 1 5
      Prints a random ID for each fixed idea number, in a random order, for
      example "K=7 B=3 Q=1 Z=9 D=5". Put the ideas in the brief in this order.

  judge.py check "<map>" "<picked IDs>" "<cut IDs or none>" <n>
      Checks a judge's answer against the map: n distinct picked IDs from the
      map, no overlap with the cut IDs, and every ID in one list. Prints the
      fixed numbers of the picked ideas, best first, or exits 1 with a reason.
"""
import random
import string
import sys


def fail(msg):
    print(f"bad answer: {msg}", file=sys.stderr)
    sys.exit(1)


def ids(text):
    text = text.replace(",", " ").strip()
    return [] if text.lower() in ("", "none") else text.upper().split()


def main(argv):
    if len(argv) >= 2 and argv[0] == "map":
        nums = argv[1:]
        if len(set(nums)) != len(nums):
            sys.exit("map: idea numbers must be distinct")
        letters = random.sample(string.ascii_uppercase, len(nums))
        print(*(f"{l}={n}" for l, n in zip(letters, random.sample(nums, len(nums)))))
        return
    if len(argv) == 5 and argv[0] == "check":
        try:
            m = dict(pair.split("=", 1) for pair in argv[1].split())
        except ValueError:
            sys.exit("check: the map must look like 'K=7 B=3'")
        picked, cut, n = ids(argv[2]), ids(argv[3]), int(argv[4])
        if len(picked) != n:
            fail(f"{len(picked)} picked, expected {n}")
        if len(set(picked)) != len(picked):
            fail("an ID is picked twice")
        unknown = (set(picked) | set(cut)) - set(m)
        if unknown:
            fail(f"unknown IDs {sorted(unknown)}")
        if set(picked) & set(cut):
            fail(f"IDs both picked and cut {sorted(set(picked) & set(cut))}")
        missing = set(m) - set(picked) - set(cut)
        if missing:
            fail(f"IDs neither picked nor cut {sorted(missing)}")
        if len(cut) != len(set(cut)):
            fail("an ID is cut twice")
        print(*(m[i] for i in picked))
        return
    sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
