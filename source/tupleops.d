module tupleops;

import std.stdio;
import std.typecons;


private auto _mapImpl(alias func, Ts...)(return auto ref Ts ts)
{
    import std.traits : Parameters;

    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            static if (is(Tuple!(Parameters!func) == typeof(ts[0])))
                return tuple(func(ts[0].expand));
            else
                return tuple(_mapImpl!func(ts[0].expand));
        }
        else
            static if (is(Tuple!(Parameters!func) == typeof(ts[0])))
                return tuple(func(ts[0].expand),
                             _mapImpl!func(ts[1 .. $]).expand);
            else
                return tuple(_mapImpl!func(ts[0].expand),
                             _mapImpl!func(ts[1 .. $]).expand);
    }
    else
    {
        static if (ts.length == 1)
            return tuple(func(ts[0]));
        else
            return tuple(func(ts[0]),
                         _mapImpl!func(ts[1 .. $]).expand);
    }
}

/// simple map over tuples
auto map(alias func, Ts...)(return auto ref Ts ts)
{
    return _mapImpl!func(ts)[0];
}

///
unittest
{
    enum t0 = tuple(1, 2, 3);
    static assert(map!(x => x)(t0) == t0);
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(map!(x => x)(t) == t);

    assert(map!(x => 2 * x)(t0) == tuple(2, 4, 6));
    static assert(map!(x => 2 * x)(t) ==
                  tuple(2, 4, tuple(6, tuple(tuple(8, 10), 12), 14)));

    static assert(map!((int x, int y) => x + y)(tuple(1, 2)) == 3);
    static assert(map!((int x, int y) => x + y)(
                      tuple(tuple(1, 2),
                            tuple(tuple(3, 4), tuple(5, 6))))
                  == tuple(3, tuple(7, 11)));
}

/// equivalent to boost::hana::overload
template overload(funcs ...)
{
    static foreach (f; funcs) alias overload = f;
}

///
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

    // FIXME apply longest argument overload by getOverloads
    enum t2 = tuple(1.0, 2, tuple(3.0, tuple(tuple(4, 5), 6), 7.0));
    writeln(map!f(t2)); //  == tuple(2.0, "2", tuple(6.0, tuple(tuple(9), "6"), 14.0)));

}


/// higher order function for mapping via depth-fisrt search
auto depthFirstFlatMap(alias func, Ts ...)(return auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return depthFirstFlatMap!func(ts[0].expand);
        }
        else
        {
            return tuple(depthFirstFlatMap!func(ts[0].expand).expand,
                         depthFirstFlatMap!func(ts[1..$]).expand);
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
                         depthFirstFlatMap!func(ts[1..$]).expand);
        }
    }
}

/// depth-first map iterates by left-to-right search.
unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(depthFirstFlatMap!(x => x)(t) == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// higher order function for mapping via bread-fisrt search
auto breadFirstFlatMap(alias func, Ts ...)(return auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return breadFirstFlatMap!func(ts[0].expand);
        }
        else
        {
            return breadFirstFlatMap!func(ts[1..$], ts[0].expand);
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
                         breadFirstFlatMap!func(ts[1..$]).expand);
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
    static assert(breadFirstFlatMap!(x => x)(t) == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// flatten nested tuple into 1-d tuple with copies of elements
auto flatten(alias map = depthFirstFlatMap, Ts ...)(return auto ref Ts ts)
{
    return map!((return auto ref x) => x)(ts);
}

///
unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(t.flatten == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// flatten nested tuple into 1-d tuple with pointers of elements
auto ptrs(alias map = depthFirstFlatMap, Ts ...)(return ref Ts ts)
{
    return map!((return ref x) => &x)(ts);
}

///
unittest
{
    auto t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    auto p = t.ptrs;
    *p[1] = 222;
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
