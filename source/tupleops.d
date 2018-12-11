module tupleops;

import std.stdio;
import std.typecons;

template LongestOverload(alias func)
{
    private import std.traits : Parameters;

    struct S
    {
        alias f = func;
    }

    enum maxIndex = {
        size_t maxIdx, maxLen;
        foreach (i, _f; __traits(getOverloads, S, "f"))
        {
            auto plen = Parameters!(_f).length;
            if (plen > maxLen)
            {
                maxIdx = i;
                maxLen = plen;
            }
        }
        return maxIdx;
    }();

    static foreach (i, _f; __traits(getOverloads, S, "f"))
    {
        static if (i == maxIndex)
        {
            alias func = _f;
            alias Types = Parameters!_f;
        }
    }
}

version (unittest)
{
    void f(int x) {}
    void f(int x, int y) {}
    void f(int x, int y, double z) {}
}

unittest
{
    import std.meta : AliasSeq;
    static assert(is(LongestOverload!f.Types == AliasSeq!(int, int, double)));

    alias g = overload!(
        (int x) {},
        (int x, int y) {},
        (int x, int y, double z) {}
        );
    static assert(is(LongestOverload!g.Types == AliasSeq!(int, int, double)));
}


private auto _mapImpl(alias func, Ts...)(return auto ref Ts ts)
{
    alias T = typeof(ts[0]);
    enum isLongest = is(Tuple!(LongestOverload!func.Types) == T);

    static if (isTuple!T)
    {
        static if (ts.length == 1)
        {
            static if (isLongest)
                return tuple(func(ts[0].expand));
            else
                return tuple(_mapImpl!func(ts[0].expand));
        }
        else
        {
            static if (isLongest)
                return tuple(func(ts[0].expand),
                             _mapImpl!func(ts[1 .. $]).expand);
            else
                return tuple(_mapImpl!func(ts[0].expand),
                             _mapImpl!func(ts[1 .. $]).expand);
        }
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

    // apply longest argument overload
    enum t1 = tuple(1.0, 2, tuple(3, 4));
    static assert(map!f(t1)  == tuple(2.0, "2", 7));

    enum t2 = tuple(1.0, 2, tuple(3.0, tuple(tuple(4, 5), 6), 7.0));
    static assert(map!f(t2)  == tuple(2.0, "2", tuple(6.0, tuple(9, "6"), 14.0)));
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

auto _foldLeftImpl(alias func, Accumulator, Ts ...)(Accumulator acc, Ts ts)
{
    static if (ts.length == 1)
    {
        return func(acc, ts[0]);
    }
    else
    {
        return _foldLeftImpl!func(func(acc, ts[0]), ts[1 .. $]);
    }
}

/// simple fold left over tuples
auto foldLeft(alias func, Accumulator, Ts ...)(Accumulator acc, Ts ts)
{
    static if (ts.length == 1 && isTuple!(Ts[0]))
    {
        return _foldLeftImpl!func(acc, ts[0].expand);
    }
    else
    {
        return _foldLeftImpl!func(acc, ts);
    }
}

/// depth-first map iterates by left-to-right search.
unittest
{
    import std.conv : to;

    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    static assert(foldLeft!((a, b) => a ~ b.to!string ~ ", ")("", t) ==
                  "1, 2, Tuple!(int, Tuple!(Tuple!(int, int), int), int)(3, Tuple!(Tuple!(int, int), int)(Tuple!(int, int)(4, 5), 6), 7), ");
}

/// static map over tuples
auto ctMap(alias func, Ts...)(Ts ts)
{
    return foldLeft!(
        (a, b)
        {
            return tuple(a.expand, func!b);
        })(tuple(), ts);
}

version (unittest) {
    enum strof(alias x) = typeof(x).stringof;
}

///
unittest
{
    enum a = 1;
    enum b = "b";
    //     function should be global
    //     enum strof(alias x) = typeof(x).stringof;
    static assert(ctMap!strof(a, b) == tuple("int", "string"));
}

/// static filter using template arg
auto ctFilter(alias func, Ts ...)(Ts ts) {
    return foldLeft!(
        (a, b)
        {
            static if (func!(b))
            {
                return tuple(a.expand, b);
            }
            else
            {
                return a;
            }
        })(tuple(), ts);
}

version (unittest) {
    enum pred(alias b) = isTuple!(typeof(b));
}

/// static filter example
unittest
{
    enum t = tuple(1, 2, tuple(3), tuple(4), 5, tuple(6));
    // pred should be global
    // private enum pred(alias b) = isTuple!(typeof(b));
    static assert(t.ctFilter!pred == tuple(tuple(3), tuple(4), tuple(6)));
}

version (unittest) {
    struct T {
        // int a;
        // double b;
        static void f() {}
        static int g(int i) { return i; }
    }

    // alias member(name ...) =  __traits(getMember, T, name[0]);
    import std.traits : isSomeFunction;
    enum isMemberFunction(alias name) = isSomeFunction!(__traits(getMember, T, name));
}

// TODO find nice way to handle AliasSeq
unittest
{
    import std.meta;
    enum names = tuple(__traits(allMembers, T));
    names.ctMap!isSomeFunction;
    alias funcs = AliasSeq!(T.f, T.g);
    // enum memberFunctions = names.ctFilter!isMemberFunction;
    // memberFunctions.writeln;
}

/// higher order function for reduction from left via depth-fisrt search
auto depthFirstFoldLeft(alias func, Accumulator, Ts ...)(Accumulator acc, auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return depthFirstFoldLeft!func(acc, ts[0].expand);
        }
        else
        {
            return depthFirstFoldLeft!func(depthFirstFoldLeft!func(acc, ts[0].expand),
                                               ts[1..$]);
        }
    }
    else
    {
        static if (ts.length == 1)
        {
            return func(acc, ts[0]);
        }
        else
        {
            return depthFirstFoldLeft!func(func(acc, ts[0]), ts[1..$]);
        }
    }
}

/// depth-first fold left
unittest
{
    enum t = tuple(1, 2, tuple(3, tuple(tuple(4, 5), 6), 7));
    import std.stdio;
    import std.conv : to;
    static assert(depthFirstFoldLeft!((a, b) => (a ~ b.to!string))("", t) == "1234567");
    // TODO(karita) replace depthFirstFlatMap with depthFirstFoldLeft
    static assert(depthFirstFoldLeft!((a, b) => tuple(a.expand, b))(tuple(), t) == tuple(1, 2, 3, 4, 5, 6, 7));
}


/// higher order function for mapping via breadth-fisrt search
auto breadthFirstFlatMap(alias func, Ts ...)(return auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return breadthFirstFlatMap!func(ts[0].expand);
        }
        else
        {
            return breadthFirstFlatMap!func(ts[1..$], ts[0].expand);
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
                         breadthFirstFlatMap!func(ts[1..$]).expand);
        }
    }
}

/// breadth-first map iterates by top-to-bottom search.
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
    static assert(breadthFirstFlatMap!(x => x)(t) == tuple(1, 2, 3, 4, 5, 6, 7));
}

/// higher order function for fold left via breadth-fisrt search
auto breadthFirstFoldLeft(alias func, Accumulator, Ts ...)(Accumulator acc, auto ref Ts ts)
{
    static if (isTuple!(typeof(ts[0])))
    {
        static if (ts.length == 1)
        {
            return breadthFirstFoldLeft!func(acc, ts[0].expand);
        }
        else
        {
            return breadthFirstFoldLeft!func(acc, ts[1..$], ts[0].expand);
        }
    }
    else
    {
        static if (ts.length == 1)
        {
            return func(acc, ts[0]);
        }
        else
        {
            return breadthFirstFoldLeft!func(func(acc, ts[0]), ts[1..$]);
        }
    }
}

/// breadth-first map iterates by top-to-bottom search.
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
    static assert(breadthFirstFoldLeft!((a, b) => tuple(a.expand, b))(tuple(), t) == tuple(1, 2, 3, 4, 5, 6, 7));
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
