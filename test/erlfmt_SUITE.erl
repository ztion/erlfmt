%% Copyright (c) Facebook, Inc. and its affiliates.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(erlfmt_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

%% Test server callbacks
-export([
    suite/0,
    all/0,
    groups/0,
    group/1,
    init_per_suite/1, end_per_suite/1,
    init_per_group/2, end_per_group/2,
    init_per_testcase/2, end_per_testcase/2
]).

%% Test cases
-export([
    records/1,
    attributes/1,
    specs/1,
    macro_call_exprs/1,
    macro_call_pats/1,
    macro_call_types/1,
    macro_definitions/1,
    functions_and_funs/1,
    operators/1,
    lists/1,
    binaries/1,
    clauses/1,
    types/1,
    annos/1,
    smoke_test_cli/1
]).

suite() ->
    [{timetrap, {seconds, 10}}].

init_per_suite(Config) ->
    Config.

end_per_suite(_Config) ->
    ok.

init_per_group(_GroupName, Config) ->
    Config.

end_per_group(_GroupName, _Config) ->
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, _Config) ->
    ok.

groups() ->
    [
        {parser, [parallel], [
            records,
            attributes,
            specs,
            macro_call_exprs,
            macro_call_pats,
            macro_call_types,
            macro_definitions,
            functions_and_funs,
            operators,
            lists,
            binaries,
            clauses,
            types,
            annos
        ]},
        {smoke_tests, [parallel], [
            smoke_test_cli
        ]}
    ].

group(_) -> [].

all() ->
    [{group, smoke_tests}, {group, parser}].

%%--------------------------------------------------------------------
%% TEST CASES

records(Config) when is_list(Config) ->
    ?assertMatch(
        {record, _, {atom, _, foo}, []},
        parse_expr("#foo{}")
    ),
    ?assertMatch(
        {record_index, _, {atom, _, foo}, {atom, _, bar}},
        parse_expr("#foo.bar")
    ),
    ?assertMatch(
        {record_field, _, {var, _, 'X'}, {atom, _, foo}, {atom, _, bar}},
        parse_expr("X#foo.bar")
    ),
    ?assertMatch(
        {record, _, {var, _, 'X'}, {atom, _, foo}, []},
        parse_expr("X#foo{}")
    ),
    ?assertMatch(
        {attribute, _,record, [{atom, _, foo}, {tuple, _, [
            {typed, _, {record_field, _, {atom, _, a}, {integer, _, 1}}, {call, _, {atom, _, integer}, []}},
            {typed, _, {record_field, _, {atom, _, b}}, {call, _, {atom, _, float}, []}},
            {record_field, _, {atom, _, c}, {integer, _, 2}},
            {record_field, _, {atom, _, d}}
        ]}]},
        parse_form("-record(foo, {a = 1 :: integer(), b :: float(), c  = 2, d}).")
    ),
    ?assertMatch(
        {attribute, _, type, [{typed, _,
            {call, _, {atom, _, foo}, []},
            {record, _, {atom, _, foo}, []}
        }]},
        parse_form("-type foo() :: #foo{}.")
    ),
    ?assertMatch(
        {attribute, _, opaque, [{typed, _,
            {call, _, {atom, _, foo}, []},
            {record, _, {atom, _, foo}, []}
        }]},
        parse_form("-opaque foo() :: #foo{}.")
    ).

attributes(Config) when is_list(Config) ->
    ?assertMatch(
        {attribute, _, foo, [{atom, _, bar}]},
        parse_form("-foo(bar).")
    ),
    ?assertMatch(
        {attribute, _, ifdef, [{atom, _, foo}]},
        parse_form("-ifdef(foo).")
    ),
    ?assertMatch(
        {attribute, _, 'if', [{op, _, '==', {macro_call, _, {atom, _, foo}, none}, {integer, _, 2}}]},
        parse_form("-if(?foo == 2).")
    ),
    ?assertMatch(
        {attribute, _, else, []},
        parse_form("-else.")
    ),
    ?assertMatch(
        {attribute, _, endif, []},
        parse_form("-endif.")
    ),
    ?assertMatch(
        {attribute, _, endif, [{macro_call, _, {var, _, 'BAR'}, none}]},
        parse_form("-endif(?BAR).")
    ),
    ?assertMatch(
        {attribute, _, export, [{list, _, [
            {op, _, '/', {macro_call, _, {var, _, 'FOO'}, none}, {integer, _, 1}},
            {op, _, '/', {atom, _, foo}, {integer, _, 2}}
        ]}]},
        parse_form("-export([?FOO/1, foo/2]).")
    ),
    ?assertMatch(
        {attribute, _, import, [
            {atom, _, foo},
            {list, _, [{op, _, '/', {atom, _, bar}, {integer, _, 1}}]}
        ]},
        parse_form("-import(foo, [bar/1]).")
    ),
    ?assertMatch(
        {attribute, _, something_else, [
            {tuple, _, [{atom, _, foo}, {op, _, '/', {atom, _, bar}, {integer, _, 1}}]}
        ]},
        parse_form("-something_else({foo, bar/1}).")
    ).

specs(Config) when is_list(Config) ->
    ?assertMatch(
        {attribute, _, spec, [{spec, _,
            {remote, _, {atom, _, foo}, {atom, _, bar}},
            [{clause, _, spec, [], [], [{atom, _, ok}]}]
        }]},
        parse_form("-spec foo:bar() -> ok.")
    ),
    ?assertMatch(
        {attribute, _, spec, [{spec, _, {atom, _, foo}, [
            {clause, _, spec, [{call, _, {atom, _, integer}, []}], [], [{atom, _,integer}]},
            {clause, _, spec, [{call, _, {atom, _, atom}, []}], [], [{atom, _, atom}]}
        ]}]},
        parse_form("-spec foo(integer()) -> integer; (atom()) -> atom.")
    ),
    ?assertMatch(
        {attribute, _, callback, [{spec, _, {atom, _, foo}, [
            {clause, _, spec, [{var, _, 'X'}],
                [[
                    {typed, _, {var, _, 'X'}, {call, _, {atom, _, integer}, []}},
                    {typed, _, {var, _, 'Y'}, {call, _, {atom, _, atom}, []}}
                ]],
                [{var, _, 'Y'}]}
        ]}]},
        parse_form("-callback foo(X) -> Y when X :: integer(), Y :: atom().")
    ),
    ?assertMatch(
        {attribute, _, spec, [{spec, _,
            {macro_call, _, {atom, _, foo}, none},
            [{clause, _, spec, [], [], [{atom, _, ok}]}]
        }]},
        parse_form("-spec ?foo() -> ok.")
    ),
    ?assertMatch(
        {attribute, _, callback, [{spec, _,
            {macro_call, _, {var, _, 'FOO'}, none},
            [{clause, _, spec, [], [], [{atom, _, ok}]}]
        }]},
        parse_form("-callback ?FOO() -> ok.")
    ).


macro_call_exprs(Config) when is_list(Config) ->
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, none},
        parse_expr("?FOO")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, []},
        parse_expr("?FOO()")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, [{integer, _, 1}]},
        parse_expr("?FOO(1)")
    ),
    ?assertMatch(
        {macro_string, _, {var, _, 'FOO'}},
        parse_expr("??FOO")
    ),
    ?assertMatch(
        {macro_call, _, {atom, _, foo}, [{guard, _, {atom, _, x}, {atom, _, true}}]},
        parse_expr("?foo(x when true)")
    ),
    ?assertMatch(
        {concat, _, [{macro_call, _, {atom, _, foo}, none}, {string, _, "suffix"}]},
        parse_expr("?foo \"suffix\"")
    ),
    ?assertMatch(
        {concat, _, [{macro_string, _, {atom, _, foo}}, {string, _, "suffix"}]},
        parse_expr("??foo \"suffix\"")
    ),
    ?assertMatch(
        {concat, _, [{var, _, 'Var'}, {string, _, "suffix"}]},
        parse_expr("Var \"suffix\"")
    ),
    ?assertMatch(
        {concat, _, [{string, _, "prefix"}, {string, _, "suffix"}]},
        parse_expr("\"prefix\" \"suffix\"")
    ),
    ?assertMatch(
        {concat, _, [{string, _, "prefix"}, {macro_call, _, {atom, _, foo}, none}]},
        parse_expr("\"prefix\" ?foo")
    ),
    ?assertMatch(
        {concat, _, [{string, _, "prefix"}, {macro_string, _, {atom, _, foo}}]},
        parse_expr("\"prefix\" ??foo")
    ),
    ?assertMatch(
        {concat, _, [{string, _, "prefix"}, {var, _, 'Var'}]},
        parse_expr("\"prefix\" Var")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_expr("?foo{}")
    ),
    ?assertMatch(
        {record_index, _, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_expr("?foo.bar")
    ),
    ?assertMatch(
        {record, _, {var, _, 'S'}, {macro_call, _, {atom, _, foo}, none}, []},
        parse_expr("S?foo{}")
    ),
    ?assertMatch(
        {record_field, _, {var, _, 'S'}, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_expr("S?foo.bar")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_expr("#?foo{}")
    ),
    ?assertMatch(
        {record_index, _, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_expr("#?foo.bar")
    ),
    ?assertMatch(
        {record, _, {var, _, 'S'}, {macro_call, _, {atom, _, foo}, none}, []},
        parse_expr("S#?foo{}")
    ),
    ?assertMatch(
        {record_field, _, {var, _, 'S'}, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_expr("S#?foo.bar")
    ),
    ?assertMatch(
        {record_index, _, {atom, _, foo}, {var, _, 'Bar'}},
        parse_expr("#foo.Bar")
    ),
    ?assertMatch(
        {record_field, _, {var, _, 'S'}, {atom, _, foo}, {var, _, 'Bar'}},
        parse_expr("S#foo.Bar")
    ).

macro_call_pats(Config) when is_list(Config) ->
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, none},
        parse_pat("?FOO")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, []},
        parse_pat("?FOO()")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, [{integer, _, 1}]},
        parse_pat("?FOO(1)")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_pat("?foo{}")
    ),
    ?assertMatch(
        {record_index, _, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_pat("?foo.bar")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_pat("#?foo{}")
    ),
    ?assertMatch(
        {record_index, _, {macro_call, _, {atom, _, foo}, none}, {atom, _, bar}},
        parse_pat("#?foo.bar")
    ),
    ?assertMatch(
        {record_index, _, {atom, _, foo}, {var, _, 'Bar'}},
        parse_pat("#foo.Bar")
    ).

macro_call_types(Config) when is_list(Config) ->
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, none},
        parse_type("?FOO")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, []},
        parse_type("?FOO()")
    ),
    ?assertMatch(
        {macro_call, _, {var, _, 'FOO'}, [{op, _, '|', {integer, _, 1}, {integer, _, 2}}]},
        parse_type("?FOO(1 | 2)")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_type("?foo{}")
    ),
    ?assertMatch(
        {record, _, {macro_call, _, {atom, _, foo}, none}, []},
        parse_type("#?foo{}")
    ).

macro_definitions(Config) when is_list(Config) ->
    ?assertMatch(
        {attribute, _, define, [{var, _, 'FOO'}, [[{atom, _, foo}]]]},
        parse_form("-define(FOO, foo).")
    ),
    ?assertMatch(
        {attribute, _, define, [{call, _, {var, _, 'FOO'}, []}, [[{atom, _, foo}]]]},
        parse_form("-define(FOO(), foo).")
    ),
    ?assertMatch(
        {attribute, _, define, [{call, _, {var, _, 'FOO'}, [{var, _, 'X'}]}, [[{atom, _, foo}]]]},
        parse_form("-define(FOO(X), foo).")
    ),
    ?assertMatch(
        {attribute, _, define, [{call, _, {atom, _, is_nice}, [{var, _, 'X'}]}, [[
            {call, _, {atom, _, is_tuple}, [{var, _, 'X'}]},
            {op, _, '=:=', {call, _, {atom, _,element}, [{integer, _, 1},{var, _, 'X'}]}, {atom, _, nice}}
        ]]]},
        parse_form("-define(is_nice(X), is_tuple(X), element(1, X) =:= nice).")
    ),
    ?assertMatch(
        {attribute, _, define, [{atom, _, foo}, {record_name, _, {atom, _,bar}}]},
        parse_form("-define(foo, #bar).")
    ),
    ?assertMatch(
        {attribute, _, define, [{atom, _, foo}, empty]},
        parse_form("-define(foo,).")
    ),
    ?assertMatch(
        {attribute, _, define, [{call, _, {atom, _, pass}, [{var, _, 'Name'}]},
            [[{'fun', _, {function, {var, _, 'Name'}, {integer, _, 2}}}]]
        ]},
        parse_form("-define(pass(Name), fun Name/2).")
    ),
    ?assertMatch(
        {attribute, _, define, [{atom, _, foo}, {clause, _, {atom, _, foo}, [], [], [{atom, _, ok}]}]},
        parse_form("-define(foo, foo() -> ok).")
    ),
    ?assertMatch(
        {attribute, _, define, [{call, _, {var, _, 'FOO'}, [{var, _, 'Name'}]},
            {clause, _, {var, _, 'Name'}, [], [], [{atom, _, ok}]}
        ]},
        parse_form("-define(FOO(Name), Name() -> ok).")
    ),
    ?assertMatch(
        {attribute, _, define, [{var, _, 'HASH_FUN'}, [[{remote, _, {atom, _, erlang}, {atom, _, phash}}]]]},
        parse_form("-define(HASH_FUN, erlang:phash).")
    ).

functions_and_funs(Config) when is_list(Config) ->
    ?assertMatch(
        {'fun', _, {function, {atom, _, foo}, {integer, _, 1}}},
        parse_expr("fun foo/1")
    ),
    ?assertMatch(
        {'fun', _, {function, {macro_call, _, {atom, _, foo}, none}, {integer, _, 1}}},
        parse_expr("fun ?foo/1")
    ),
    ?assertMatch(
        {'fun', _, {function, {atom, _, foo}, {macro_call, _, {atom, _, foo}, none}}},
        parse_expr("fun foo/?foo")
    ),
    ?assertMatch(
        {'fun', _, {function, {var, _, 'Mod'}, {atom, _, foo}, {integer, _, 1}}},
        parse_expr("fun Mod:foo/1")
    ),
    ?assertMatch(
        {'fun', _, {function, {macro_call, _, {atom, _, 'foo'}, none}, {atom, _, foo}, {integer, _, 1}}},
        parse_expr("fun ?foo:foo/1")
    ),
    ?assertMatch(
        {'fun', _, {function, {atom, _, foo}, {macro_call, _, {atom, _, foo}, none}, {integer, _, 1}}},
        parse_expr("fun foo:?foo/1")
    ),
    ?assertMatch(
        {'fun', _, {function, {atom, _, foo}, {atom, _, foo}, {macro_call, _, {atom, _, foo}, none}}},
        parse_expr("fun foo:foo/?foo")
    ),
    ?assertMatch(
        {'fun', _, {clauses, [{clause, _, 'fun', [], [], [{atom, _, ok}]}]}},
        parse_expr("fun () -> ok end")
    ),
    ?assertMatch(
        {'fun', _, {clauses, [{clause, _, {var, _, 'Foo'}, [], [], [{atom, _, ok}]}]}},
        parse_expr("fun Foo() -> ok end")
    ),
    ?assertMatch(
        {function, _, [{clause, _, {atom, _, foo}, [], [], [{atom, _, ok}]}]},
        parse_form("foo() -> ok.")
    ),
    ?assertMatch(
        {function, _, [{clause, _, {macro_call, _, {var, _, 'FOO'}, none}, [], [], [{atom, _, ok}]}]},
        parse_form("?FOO() -> ok.")
    ),
    ?assertMatch(
        {function, _, [
            {clause, _, {atom, _, foo}, [], [], [{atom, _, ok}]},
            {macro_call, _, {atom, _, bar}, []}
        ]},
        parse_form("foo() -> ok; ?bar().")
    ),
    ?assertMatch(
        {function, _, [{macro_call, _, {var, _,'TESTS_WITH_SETUP'}, [
            {atom, _, all_tests_},
            {'fun', _, {clauses, [{clause, _, 'fun', [], [], [{atom, _, ok}]}]}}
        ]}]},
        parse_form("?TESTS_WITH_SETUP(all_tests_, fun() -> ok end).")
    ).

operators(Config) when is_list(Config) ->
    ?assertMatch(
        {op, _, '=', {integer, _, 1}, {integer, _, 2}},
        parse_expr("1 = 2")
    ),
    ?assertMatch(
        {op, _, '=', {integer, _, 1}, {integer, _, 2}},
        parse_pat("1 = 2")
    ),
    ?assertMatch(
        {op, _, 'catch', {integer, _, 1}},
        parse_expr("catch 1")
    ).

lists(Config) when is_list(Config) ->
    ?assertMatch(
        {list, _, []},
        parse_expr("[]")
    ),
    ?assertMatch(
        {list, _, [{integer, _, 1}, {integer, _, 2}]},
        parse_expr("[1,2]")
    ),
    ?assertMatch(
        {list, _, [{cons, _, {integer, _, 1}, {integer, _, 2}}]},
        parse_expr("[1 | 2]")
    ),
    ?assertMatch(
        {list, _, [{integer, _, 1}, {cons, _, {integer, _, 2}, {integer, _, 3}}]},
        parse_expr("[1, 2 | 3]")
    ),
    ?assertMatch(
        {list, _, [{cons, _,
            {op, _, 'catch', {integer, _, 1}},
            {op, _, '!', {integer, _, 2}, {integer, _,3}}
        }]},
        parse_expr("[catch 1 | 2 ! 3]")
    ).

binaries(Config) when is_list(Config) ->
    ?assertMatch(
        {bin, _, [{bin_element, _, {integer, _, 1}, {integer, _, 4}, default}]},
        parse_expr("<<1:4>>")
    ).

clauses(Config) when is_list(Config) ->
    ?assertMatch(
        {'if', _, [{clause, _, 'if', [], [[{atom, _, true}]], [{atom, _, ok}]}]},
        parse_expr("if true -> ok end")
    ),
    ?assertMatch(
        {'case', _, {var, _, 'X'}, [
            {clause, _, 'case', [{atom, _, true}], [], [{atom, _, ok}]}
        ]},
        parse_expr("case X of true -> ok end")
    ),
    ?assertMatch(
        {'receive', _, [{clause, _, 'case', [{var, _, '_'}], [], [{atom, _, true}]}]},
        parse_expr("receive _ -> true end")
    ),
    ?assertMatch(
        {'try', _, [{atom, _, ok}],
            [{clause, _, 'case', [{var, _,'_'}], [], [{atom, _, ok}]}],
            [
                {clause, _, 'catch', [{var, _, '_'}], [], [{atom, _, ok}]},
                {clause, _, 'catch', [{var, _, '_'}, {var, _, '_'}], [], [{atom, _, ok}]},
                {clause, _, 'catch', [{var, _, '_'}, {var, _, '_'}, {var, _, '_'}], [], [{atom, _, ok}]}
            ],
            []
        },
        parse_expr("try ok of _ -> ok catch _ -> ok; _:_ -> ok; _:_:_ -> ok end")
    ).

types(Config) when is_list(Config) ->
    ?assertMatch(
        {typed, _, {var, _, 'Foo'}, {atom, _, foo}},
        parse_type("Foo :: foo")
    ),
    ?assertMatch(
        {op, _, '|', {var, _, 'Foo'}, {var, _, 'Bar'}},
        parse_type("Foo | Bar")
    ),
    ?assertMatch(
        {op, _, '..', {integer, _, 1}, {var, _, 'Bar'}},
        parse_type("1..Bar")
    ),
    ?assertMatch(
        {op, _, '+', {op, _, '-', {integer, _, 1}}, {op, _, '*', {integer, _, 2}, {integer, _, 3}}},
        parse_type("- 1 + 2 * 3")
    ),
    ?assertMatch(
        {tuple, _, [
            {call, _, {atom, _, foo}, []},
            {call, _, {remote, _, {atom, _, foo}, {atom, _, bar}}, []}
        ]},
        parse_type("{foo(), foo:bar()}")
    ),
    ?assertMatch(
        {list, _, [{list, _, [{list, _, []}]}, {'...', _}]},
        parse_type("[[[]], ...]")
    ),
    ?assertMatch(
        {map, _, [
            {map_field_exact, _, {map, _, []}, {integer, _, 1}},
            {map_field_assoc, _, {tuple, _, []}, {integer, _, 2}}
        ]},
        parse_type("#{#{} := 1, {} => 2}")
    ),
    ?assertMatch(
        {tuple, _, [
            {bin, _, []},
            {bin, _, [{bin_element, _, {var, _, '_'}, {integer, _, 8}, default}]},
            {bin, _, [
                {bin_element, _, {var, _, '_'}, {bin_size, _, {var, _, '_'}, {integer, _, 8}}, default}
            ]},
            {bin, _, [
                {bin_element, _, {var, _, '_'}, {integer, _, 8}, default},
                {bin_element, _, {var, _, '_'}, {bin_size, _, {var, _, '_'}, {integer, _, 4}}, default}
            ]}
        ]},
        parse_type("{<<>>, <<_:8>>, <<_:_*8>>, <<_:8, _:_*4>>}")
    ),
    ?assertMatch(
        {'fun', _, type},
        parse_type("fun()")
    ),
    ?assertMatch(
        {'fun', _, {type, [{'...', _}], {call, _, {atom, _, integer}, []}}},
        parse_type("fun((...) -> integer())")
    ),
    ?assertMatch(
        {'fun', _, {type, [], {atom, _, ok}}},
        parse_type("fun(() -> ok)")
    ),
    ?assertMatch(
        {'fun', _, {type, [{call, _, {atom, _, integer}, []}], {call, _, {atom, _,integer}, []}}},
        parse_type("fun((integer()) -> integer())")
    ).

annos(Config) when is_list(Config) ->
    %% We parse with leading \n to avoid accounting for extra stuff parse_expr does
    ?assertMatch(
        {integer, #{location := {2, 1}, end_location := {2, 4}, text := "100"}, 100},
        parse_expr("\n100")
    ),
    ?assertMatch(
        {float, #{location := {2, 1}, end_location := {2, 5}, text := "10.0"}, 10.0},
        parse_expr("\n10.0")
    ),
    ?assertMatch(
        {char, #{location := {2, 1}, end_location := {2, 4}, text := "$\\s"}, $\s},
        parse_expr("\n$\\s")
    ),
    ?assertMatch(
        {atom, #{location := {2, 1}, end_location := {2, 4}, text := "foo"}, foo},
        parse_expr("\nfoo")
    ),
    ?assertMatch(
        {string, #{location := {2, 1}, end_location := {2, 6}, text := "\"foo\""}, "foo"},
        parse_expr("\n\"foo\"")
    ),
    ?assertMatch(
        {var, #{location := {2, 1}, end_location := {2, 4}, text := "Foo"}, 'Foo'},
        parse_expr("\nFoo")
    ),
    ?assertMatch(
        {atom, #{pre_comments := [{comment, #{location := {2, 1}, end_location := {3, 6}}, ["%foo", "%bar"]}]}, ok},
        parse_expr(
            "\n%foo\n"
            " %bar\n"
            "ok"
        )
    ).

parse_expr(String) ->
    {function, _, [{clause, _, _, [], [], [Expr]}]} =
        parse_form("f() -> " ++ String ++ "."),
    Expr.

parse_pat(String) ->
    {function, _, [{clause, _, _, [Pat], [], [_]}]} =
        parse_form("f(" ++ String ++ ") -> ok."),
    Pat.

parse_type(String) ->
    {attribute, _, type, [{typed, _, _, Type}]} =
        parse_form("-type foo() :: " ++ String ++ "."),
    Type.

parse_form(String) ->
    case erlfmt:read_forms_string("nofile", String) of
        {ok, [Form], []} ->
            Form;
        {error, {_, Mod, Reason}} ->
            ct:fail("Expected successful parse:\n~ts\ngot: ~ts", [String, Mod:format_error(Reason)])
    end.

smoke_test_cli(Config) when is_list(Config) ->
    %% this relies on the _build structure rebar3 uses
    Escript = filename:join(code:lib_dir(erlfmt), "../../bin/erlfmt"),
    ?assertMatch("Usage: erlfmt " ++ _, os:cmd(Escript ++ " -h")).
