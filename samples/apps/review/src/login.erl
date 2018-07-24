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

	% почистить зомбочаты
	CleanUp = fun(Fullname) ->	
		Room = filename:dirname(Fullname),
		Users = lists:foldl(
			fun({user,Fullname,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_},Count) -> Count + 1;
					(_,Count) -> Count
			end, 
		0, kvs:all(user)),
		wf:info(?MODULE,"ucount -> ~p~n",[Users]),
		% чекнуть шизофрению
		if 
			Users < 3 -> 
			% если пользоватлеь осталось меньше 3х, значит в канале остались только боты
				wf:info(?MODULE,"REMOVE CHANNEL ~p~n",[Room]),
				% санитары больше нужны...
				Botname = Room ++ "/" ++ "silent_bob",
				Botname2 = Room ++ "/" ++ "pisikak",
				% slow down gracefully
				wf:send({chatbot,Botname}, {stop,Botname}),
				wf:send({chatbot,Botname2}, {stop,Botname2}),
				% удалить канал
				lists:foreach(
					fun({feed,{room,Room},_,_,_,_}) -> kvs:delete(feed,{room,Room}); 
							(_) -> ok
				end, kvs:all(feed)),
				% удалить пользователей 
				lists:foreach(
					fun({user,Fullname,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_}) -> kvs:delete(user,Fullname); 
							(_) -> ok 
				end, kvs:all(user));
			true -> 
				wf:info(?MODULE,"KEEP ALIVE CHANNEL ~p~n",[Room]),
				ok
		end
	end,
	wf:info(?MODULE,"*Clean up zombo-topics~n",[]),
	[CleanUp(U#user.id) || U <- kvs:all(user)],
	% получить уже обжитые фиды
	Feeds = kvs:all(feed),
	%wf:info(?MODULE,"feeds -> ~p~n",[Feeds]),	
	%TODO(darin-m): вывести надо бы...

	Users = kvs:all(user),
	%wf:info(?MODULE,"users -> ~p~n",[Users]),

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

	% добыть номер корытца в которое буде осуществляться раздача
	Room = wf:to_list(wf:q(room)),
	wf:info(?MODULE,"room -> ~p~n",[Room]),

	% передать управление, название комнаты(канала) и пользователя как аргументы 
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
