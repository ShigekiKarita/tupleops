# tupleops

[![Build Status](https://travis-ci.org/ShigekiKarita/tupleops.svg?branch=master)](https://travis-ci.org/ShigekiKarita/tupleops)
[![codecov](https://codecov.io/gh/ShigekiKarita/tupleops/branch/master/graph/badge.svg)](https://codecov.io/gh/ShigekiKarita/tupleops)
[![Dub version](https://img.shields.io/dub/v/tupleops.svg)](https://code.dlang.org/packages/tupleops)

Tuple operations for D language

```d
unittest
{
    import std.conv : to;
    alias f = overload!(
        (int i) => i.to!string,
        (int i, int j) => i + j,
        (double d) => d * 2);

    static assert(f(1, -2) == -1);
    static assert(f(1.0) == 2.0);
    static assert(f(1) == "1");

    enum t = tuple(1.0, 2, tuple(3.0, tuple(tuple(4, 5.0), 6), 7.0));
    static assert(map!f(t) == tuple(2.0, "2", tuple(6.0, tuple(tuple("4", 10.0), "6"), 14.0)));
}
```

- map (structural map)
- depthFirstFlatMap (used for flatten)
- breadthFirstFlatMap
- overload (useful for map functions)
- flatten
- ptrs
- unzip
