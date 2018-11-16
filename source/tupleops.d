module tupleops;

import std.typecons;

/// higher order function for mapping via depth-fisrt search
auto depthFirstMap(alias func, Ts ...)(return auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return depthFirstMap!func(ts[0].expand);
        }
        else
        {
            return tuple(depthFirstMap!func(ts[0].expand).expand,
                         depthFirstMap!func(ts[1..$]).expand);
        }
    }
    else
    {
        static if (ts.length == 1)
        {
            return tuple(func(ts[0]));
        }
        else
        {
            return tuple(func(ts[0]),
                         depthFirstMap!func(ts[1..$]).expand);
        }
    }
}

/// depth-first map iterates by left-to-right search.
unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(depthFirstMap!(x => x)(t) == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// higher order function for mapping via bread-fisrt search
auto breadFirstMap(alias func, Ts ...)(return auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return breadFirstMap!func(ts[0].expand);
        }
        else
        {
            return breadFirstMap!func(ts[1..$], ts[0].expand);
        }
    }
    else
    {
        static if (ts.length == 1)
        {
            return tuple(func(ts[0]));
        }
        else
        {
            return tuple(func(ts[0]),
                         breadFirstMap!func(ts[1..$]).expand);
        }
    }
}

/// bread-first map iterates by top-to-bottom search.
unittest
{
    enum t = tuple(1,
                   tuple(
                       tuple(
                           4,
                           tuple(
                               7)),
                       2),
                   tuple(
                       3,
                       tuple(
                           5,
                           6)));
    static assert(breadFirstMap!(x => x)(t) == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// alias for simplicity
auto map(alias func, alias impl = depthFirstMap, Ts ...)(return auto ref Ts ts)
{
    return impl!(func, Ts)(ts);
}

// unittest
// {
//     enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
//     static assert(map!(x => x * 2)(t) == tuple(2, "2", 6, "4", 10, "6", 14));
// }

///
auto flatten(alias map = depthFirstMap, Ts ...)(return auto ref Ts ts)
{
    return map!((return auto ref x) => x)(ts);
}

///
auto ptrs(alias map = depthFirstMap, Ts ...)(return ref Ts ts)
{
    return map!((return ref x) => &x)(ts);
}

///
unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(t.flatten == tuple(1, 2, 3, 4, 5, 6, 7));
}

///
unittest
{
    auto t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    auto p = t.ptrs;
    t[1] = 222;
    auto d = t.flatten;
    assert(d == tuple(1, 222, 3, 4, 5, 6, 7));

    static foreach (i; 0 .. t.length) {
        assert(*p[i] == d[i]);
    }
}

///
auto unzip(Z)(Z zipped)
{
    import std.algorithm : map;
    mixin(
        {
            import std.conv : to;
            alias Tp = typeof(Z.init.front());
            auto m = "return tuple(";
            foreach (i; 0 .. Tp.length)
            {
                m ~= "zipped.map!(x => x[" ~ i.to!string ~ "]),";
            }
            return m[0 .. $-1] ~ ");";
        }());
}

///
unittest
{
    import std.algorithm : equal;
    import std.range : zip;
    immutable a = [1, 2, 3];
    immutable b = ["a", "b", "c"];
    immutable c = [0.1, 0.2, 0.3];

    auto x = tuple(a, b, c);
    auto z = zip(x.expand);
    auto u = unzip(zip(a, b, c));
    static foreach (i; 0 .. x.length)
    {
        assert(u[i].equal(x[i]));
    }
}
