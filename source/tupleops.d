module tupleops;

import std.typecons;

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

auto flatten(Ts ...)(return auto ref Ts ts)
{
    return depthFirstMap!((return auto ref x) => x)(ts);
}

auto ptrs(Ts ...)(return ref Ts ts)
{
    return depthFirstMap!((return ref x) => &x)(ts);
}

unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(t.flatten == tuple(1, 2, 3, 4, 5, 6, 7));
}

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

struct UnzipRange(Z)
{
    Z zipped;
    alias Tp = typeof(Z.init.front());
    const size_t length = Tp.length;

    static auto opIndex(D...)(auto ref D i)
    {
        import std.array : array;
        import std.algorithm : map;
        return this.zipped.map!(x => x[i]);
    }
}


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
