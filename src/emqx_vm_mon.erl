%% Copyright (c) 2013-2019 EMQ Technologies Co., Ltd. All Rights Reserved.
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

-module(emqx_vm_mon).

-behaviour(gen_server).

%% APIs
-export([start_link/1]).

-export([ get_check_interval/0
        , set_check_interval/1
        , get_process_high_watermark/0
        , set_process_high_watermark/1
        , get_process_low_watermark/0
        , set_process_low_watermark/1
        ]).

%% gen_server callbacks
-export([ init/1
        , handle_call/3
        , handle_cast/2
        , handle_info/2
        , terminate/2
        , code_change/3
        ]).

-define(VM_MON, ?MODULE).

%%----------------------------------------------------------------------
%% API
%%----------------------------------------------------------------------

start_link(Opts) ->
    gen_server:start_link({local, ?VM_MON}, ?MODULE, [Opts], []).

get_check_interval() ->
    call(get_check_interval).

set_check_interval(Seconds) ->
    call({set_check_interval, Seconds}).

get_process_high_watermark() ->
    call(get_process_high_watermark).

set_process_high_watermark(Float) ->
    call({set_process_high_watermark, Float}).

get_process_low_watermark() ->
    call(get_process_low_watermark).

set_process_low_watermark(Float) ->
    call({set_process_low_watermark, Float}).

%%----------------------------------------------------------------------
%% gen_server callbacks
%%----------------------------------------------------------------------

init([Opts]) ->
    {ok, ensure_check_timer(#{check_interval => proplists:get_value(check_interval, Opts, 30),
                              process_high_watermark => proplists:get_value(process_high_watermark, Opts, 0.70),
                              process_low_watermark => proplists:get_value(process_low_watermark, Opts, 0.50),
                              timer => undefined,
                              is_process_alarm_set => false})}.

handle_call(get_check_interval, _From, State) ->
    {reply, maps:get(check_interval, State, undefined), State};
handle_call({set_check_interval, Seconds}, _From, State) ->
    {reply, ok, State#{check_interval := Seconds}};

handle_call(get_process_high_watermark, _From, State) ->
    {reply, maps:get(process_high_watermark, State, undefined), State};
handle_call({set_process_high_watermark, Float}, _From, State) ->
    {reply, ok, State#{process_high_watermark := Float}};

handle_call(get_process_low_watermark, _From, State) ->
    {reply, maps:get(process_low_watermark, State, undefined), State};
handle_call({set_process_low_watermark, Float}, _From, State) ->
    {reply, ok, State#{process_low_watermark := Float}};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info({timeout, Timer, check}, State = #{timer := Timer,
                                               process_high_watermark := ProcHighWatermark,
                                               process_low_watermark := ProcLowWatermark,
                                               is_process_alarm_set := IsProcessAlarmSet}) ->
    ProcessCount = erlang:system_info(process_count),
    case ProcessCount / erlang:system_info(process_limit) of
        Percent when Percent >= ProcHighWatermark ->
            alarm_handler:set_alarm({too_many_processes, ProcessCount}),
            {noreply, ensure_check_timer(State#{is_process_alarm_set := true})};
        Percent when Percent < ProcLowWatermark ->
            case IsProcessAlarmSet of
                true -> alarm_handler:clear_alarm(too_many_processes);
                false -> ok
            end,
            {noreply, ensure_check_timer(State#{is_process_alarm_set := false})}
    end.

terminate(_Reason, #{timer := Timer}) ->
    emqx_misc:cancel_timer(Timer).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%----------------------------------------------------------------------
%% Internal functions
%%----------------------------------------------------------------------
call(Req) ->
    gen_server:call(?VM_MON, Req, infinity).

ensure_check_timer(State = #{check_interval := Interval}) ->
    State#{timer := emqx_misc:start_timer(timer:seconds(Interval), check)}.
