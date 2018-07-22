-module(login).
-compile(export_all).
-include_lib("kvs/include/user.hrl").
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

%%
%% handlers
%

event(init) ->
	wf:info(?MODULE,"*Init",[]),
	% получить уже обжитые фиды
	Feeds = kvs:all(feed),
	wf:info(?MODULE,"feeds -> ~p~n",[Feeds]),	
	%TODO(darin-m): вывести надо бы...

	Users = kvs:all(user),
	wf:info(?MODULE,"users -> ~p~n",[Users]),
	ok;	


event(login) ->
	wf:info(?MODULE,"*Login",[]),
	% получить участника кормёжки
	User = case wf:q(user) of 
		<<>> -> "anonymous";
		undefined -> "anonymous";
		E -> wf:to_list(E) 
	end,  
	wf:info(?MODULE,"user -> ~p~n",[User]),
	% пихнуть в кармашек
	%FIXME(darin-m): комнату, занчит, параметром передаём, а пользоватлея через карман? Ну такое себе решеньице...
	%wf:user(User),

	% и номер корытца в которое буде осуществляться раздача
	Room = wf:to_list(wf:q(room)),
	wf:info(?MODULE,"room -> ~p~n",[Room]),

	% передать управление и название комнаты(канала) и пользователя как аргументы 
	wf:redirect("index.htm?room=" ++ Room ++ "&user=" ++ User),
	ok;


event(_Event) -> 
	wf:info(?MODULE,"*_Event -> ~p",[_Event]),
	[].


%%
%% page model
%


body() ->
	[ #span{ id=display }, #br{},
		#span{ body="Login: " }, #textbox{id=user,autofocus=true}, #br{},
		#span{ body="Join/Create Feed: " }, #textbox{id=room},
		#button{ id=loginButton, body="Spawn!",postback=login,source=[user,room]} ].

%%
%% Internals
%

folders() -> 
	string:join(
		[filename:basename(F)
			|| F<-filelib:wildcard(code:priv_dir(review) ++ "/snippets/*/")], 
		","
	).
