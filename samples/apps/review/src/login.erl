-module(login).
-compile(export_all).
-include_lib("kvs/include/feed.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("n2o/include/wf.hrl").


main() -> 
	#dtl{
		file="login",
		app=review,
		bindings=[
			{body,body()},
			{folders,folders()}
		]
	}.


folders() -> 
	string:join(
		[
			filename:basename(F)
			|| F<-filelib:wildcard(code:priv_dir(review) ++ "/snippets/*/")
		], ",").


body() ->
[ 
	#span{ id=display }, #br{},
	#span{ body="Login: " }, #textbox{id=user,autofocus=true}, #br{},
	#span{ body="Join/Create Feed: " }, #textbox{id=room},
	#button{ id=loginButton, body="Spawn!",postback=login,source=[user,room]} 
].


event(init) ->
	wf:info(?MODULE,"*Init",[]),
	% получить уже обжитые фиды
	Feeds = kvs:all(feed),
	wf:info(?MODULE,"feeds -> ~p~n",[Feeds]),	
	%TODO(darin-m): вывести надо бы...
	ok;	


event(login) ->
	wf:info(?MODULE,"*Login",[]),
	User = case wf:q(user) of 
		<<>> -> "anonymous";
		undefined -> "anonymous";
		E -> wf:to_list(E) 
	end,  
	wf:user(User),
	wf:info(?MODULE,"user -> ~p~n",[User]),
	wf:info(?MODULE,"wf_user -> ~p~n",[wf:user()]),
	Pass = wf:to_list(wf:q(pass)),
	wf:info(?MODULE,"pass -> ~p~n",[Pass]),
	wf:redirect("index.htm?room=" ++ Pass),
	ok;

event(_Event) -> 
	wf:info(?MODULE,"*_Event -> ~p",[_Event]),
	[].
