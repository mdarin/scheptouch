-module(n2o_query_handler).
-author('Maxim Sokhatsky').
-behaviour(query_handler).
-include_lib("n2o/include/wf.hrl").
-export([init/2, finish/2]).

init(State, Ctx) -> 
    Params = n2o_cowboy:params(Ctx#context.req),
%    error_logger:info_msg("Params: ~p",[Params]),
    NewCtx = Ctx#context{params=Params},
    wf_context:context(NewCtx),
    {ok, [], NewCtx}.

finish(State, Ctx) ->  {ok, [], Ctx}.
