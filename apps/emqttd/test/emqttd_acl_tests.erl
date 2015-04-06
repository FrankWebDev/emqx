%%%-----------------------------------------------------------------------------
%%% @Copyright (C) 2012-2015, Feng Lee <feng@emqtt.io>
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%%-----------------------------------------------------------------------------
%%% @doc
%%% emqttd_acl tests.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(emqttd_acl_tests).

-include("emqttd.hrl").

-ifdef(TEST).

-include_lib("eunit/include/eunit.hrl").

compile_test() ->
    ?assertMatch({allow, {ipaddr, {"127.0.0.1", _I, _I}}, subscribe, [ [<<"$SYS">>, '#'], ['#'] ]},
                 emqttd_acl:compile({allow, {ipaddr, "127.0.0.1"}, subscribe, ["$SYS/#", "#"]})),
    ?assertMatch({allow, {user, <<"testuser">>}, subscribe, [ [<<"a">>, <<"b">>, <<"c">>], [<<"d">>, <<"e">>, <<"f">>, '#'] ]},
                 emqttd_acl:compile({allow, {user, "testuser"}, subscribe, ["a/b/c", "d/e/f/#"]})),
    ?assertEqual({allow, {user, <<"admin">>}, pubsub, [ [<<"d">>, <<"e">>, <<"f">>, '#'] ]},
                 emqttd_acl:compile({allow, {user, "admin"}, pubsub, ["d/e/f/#"]})),
    ?assertEqual({allow, {client, <<"testClient">>}, publish, [ [<<"testTopics">>, <<"testClient">>] ]},
                 emqttd_acl:compile({allow, {client, "testClient"}, publish, ["testTopics/testClient"]})),
    ?assertEqual({allow, all, pubsub, [{pattern, [<<"clients">>, <<"$c">>]}]},
                 emqttd_acl:compile({allow, all, pubsub, ["clients/$c"]})),
    ?assertEqual({allow, all, subscribe, [{pattern, [<<"users">>, <<"$u">>, '#']}]},
                 emqttd_acl:compile({allow, all, subscribe, ["users/$u/#"]})),
    ?assertEqual({deny, all, subscribe, [ [<<"$SYS">>, '#'], ['#'] ]},
                 emqttd_acl:compile({deny, all, subscribe, ["$SYS/#", "#"]})),
    ?assertEqual({allow, all}, emqttd_acl:compile({allow, all})),
    ?assertEqual({deny, all},  emqttd_acl:compile({deny, all})).

match_test() ->
    User = #mqtt_user{ipaddr = {127,0,0,1}, clientid = <<"testClient">>, username = <<"TestUser">>},
    User2 = #mqtt_user{ipaddr = {192,168,0,10}, clientid = <<"testClient">>, username = <<"TestUser">>},
    
    ?assertEqual({matched, allow}, emqttd_acl:match(User, <<"Test/Topic">>, [{allow, all}])),
    ?assertEqual({matched, deny},  emqttd_acl:match(User, <<"Test/Topic">>, [{deny, all}])),
    ?assertMatch({matched, allow}, emqttd_acl:match(User, <<"Test/Topic">>,
                 emqttd_acl:compile({allow, {ipaddr, "127.0.0.1"}, subscribe, ["$SYS/#", "#"]}))),
    ?assertMatch({matched, allow}, emqttd_acl:match(User2, <<"Test/Topic">>,
                 emqttd_acl:compile({allow, {ipaddr, "192.168.0.1/24"}, subscribe, ["$SYS/#", "#"]}))),
    ?assertMatch({matched, allow}, emqttd_acl:match(User, <<"d/e/f/x">>,
                                                       emqttd_acl:compile({allow, {user, "TestUser"}, subscribe, ["a/b/c", "d/e/f/#"]}))),
    ?assertEqual(nomatch, emqttd_acl:match(User, <<"d/e/f/x">>, emqttd_access:compile({allow, {user, "admin"}, pubsub, ["d/e/f/#"]}))),
    ?assertMatch({matched, allow}, emqttd_acl:match(User, <<"testTopics/testClient">>,
                 emqttd_acl:compile({allow, {client, "testClient"}, publish, ["testTopics/testClient"]}))),
    ?assertMatch({matched, allow}, emqttd_acl:match(User, <<"clients/testClient">>,
                                                       emqttd_acl:compile({allow, all, pubsub, ["clients/$c"]}))),
    ?assertMatch({matched, allow}, emqttd_acl:match(#mqtt_user{username = <<"user2">>}, <<"users/user2/abc/def">>,
                                                                  emqttd_acl:compile({allow, all, subscribe, ["users/$u/#"]}))),
    ?assertMatch({matched, deny}, 
                 emqttd_acl:match(User, <<"d/e/f">>,
                                     emqttd_acl:compile({deny, all, subscribe, ["$SYS/#", "#"]}))).

-endif.

