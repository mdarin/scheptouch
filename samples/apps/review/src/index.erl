-module(index).
-compile(export_all).
-include_lib("kvs/include/entry.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("n2o/include/wf.hrl").


main() ->
	%case wf:user() of
	case user() of
		undefined -> 
			wf:redirect("login.htm"),
			redirect_wait();
		_ -> 
			#dtl{file = "index", app=review,bindings=[
				{body,body()},
				{list,list()},
				{javascript,(?MODULE:(wf:config(n2o,mode,dev)))()}
			]} 
	end.


%%
%% handlers
%

event(init) ->
	wf:info(?MODULE,"*Init~n",[]),

	User = user(),%wf:user(),
	wf:info(?MODULE,"user -> ~p~n",[User]),

	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),

	wf:update(upload,#upload{id=upload}),

	SessionID = n2o_session:session_id(), 
	wf:info(?MODULE,"session_id -> ~p~n",[SessionID]),

	% Ассоциировать процесс с пулом gproc(зарегистрировать)
	% присоединить по критерию "идентификатор сессии"
	%wf:reg(SessionID),
	% примкнуть к ОПГ процессов по критерию "команта"
	wf:reg({topic,Room}),

	% создать парочку идиотов прислужников дьявола
	Res = wf:async("looper",fun index:loop/1),
	n2o_async:send("looper","waterline"),
	n2o_async:send("looper","my first message!"),
	%wf:info(?MODULE,"Async Process Created: ~p at Page Pid ~p~n",[Res,self()]),
	Res2 = wf:async("looper2",fun index:loop2/1),
	n2o_async:send("looper2","my second message from another!"),

 	% показать историю сообщений в канале
	[wf:info(?MODULE,"**** from -> ~p  media -> ~p~n",[E#entry.from,E#entry.media])
		|| E <- kvs:entries(kvs:get(feed,{room,Room}),entry,10)],
	
	[event({client,{E#entry.from, E#entry.media}}) 
		|| E <- kvs:entries(kvs:get(feed,{room,Room}),entry,10)];


event(logout) ->
	wf:info(?MODULE,"*Logout~n",[]),
	wf:logout(),
	% metallica:play('turn the page'),
	wf:redirect("login.htm");


event(chat) ->
	wf:info(?MODULE,"*Chat~n",[]),

	User = user(),%wf:user(),
	wf:info(?MODULE,"user -> ~p~n",[User]),

	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),

	Message = wf:q(message),
	wf:info(?MODULE,"message -> ~p~n",[Message]),

	Id = kvs:next_id("entry",1),
	wf:info(?MODULE,"id -> ~p~n",[Id]),

	% история переписки пополнилась ещё одной мыслью, ярчайший бред продолжается
	Record = #entry{
		id=kvs:next_id("entry",1),
		from=User,
		feed_id={room,Room},
		media=Message
	},
	kvs:add(Record),

	% опубликовать очередную светлую мысль в на первой полосе Дэйли телеграф
	wf:send({topic,Room}, #client{data={User,Message}});


event(#client{data={User,Message}}) ->
	wf:info(?MODULE,"*Show message~n",[]),

	% увязать событые с элементом фомры, что ниточку прявязат к колокольчику
	wf:wire(#jq{target=message,method=[focus,select]}),

	M = wf:to_list(Message),
	wf:info(?MODULE,"m -> ~tp~n",[M]),

	DTL = #dtl{
		file="message",
		app=review,
		bindings=[{user,User},{color,"gray"},{message,M}]
	},
	wf:insert_top(history, wf:jse(wf:render(DTL)));


event(#bin{data=Data}) ->
	wf:info(?MODULE,"*Binary~n",[]),
	wf:info(?MODULE,"Binary Delivered ~p~n",[Data]),
	#bin{data = "SERVER"};


event(#ftp{sid=Sid,filename=Filename,status={event,stop}}=Data) ->
	wf:info(?MODULE,"FTP Delivered ~p~n",[Data]),
	Name = hd(lists:reverse(string:tokens(wf:to_list(Filename),"/"))),
	Link = #link{
		href=iolist_to_binary(["/static/",Sid,"/",wf:url_encode(Name)]),
		body=Name
	},
	erlang:put(message,wf:render(Link)),
	Message = wf:q(message),
	wf:info(?MODULE,"message -> ~p~n",[Message]),
	event(chat);


event(Event) ->
	wf:info(?MODULE," *_Event -> ~p", [Event]),
	ok.


%%
%% Процессы-сателлиты(Async Processes)
%

loop(M) ->
	wf:info(?MODULE,"*Loop~n",[]),
	DTL = #dtl{
		file="message",
		app=review,
		bindings=[{user,"system"},{message,M},{color,"silver"}]
	},
	wf:insert_top(history, wf:jse(wf:render(DTL))),
	wf:flush().


% моя копия неподражаемого орегинала
loop2(M) ->
	wf:info(?MODULE,"*Loop2~n",[]),
	DTL = #dtl{
		file="message",
		app=review,
		bindings=[{user,"system"},{message,M},{color,"silver"}]
	},
	wf:insert_top(history, wf:jse(wf:render(DTL))),
	%	NOTE: wf:flush/0 should be called to redirect all updates 
	% and wire actions back to the page process
	% from its async counterpart.
	wf:flush().


%TODO(darin-m): А вот и гвоздь нашей програмы чатбот Писикак!
% да, старичок, пенсионная реформа не обошла и его сотороной
% *Играет музыка*
% "..он молчит и ничего не делает Пи-Си-Как(r)(tm)!.."(с)
pisikak() -> 
	wf:info(?MODULE,"*Chatbot~n",[]),
	n2o_async:send("looper","my first message!").



%%
%% page model
%

body() ->
	wf:update(heading,
		#b{ id=heading, body="Review /App/" ++ room() }
	),
	wf:update(logout,
		%#button{ id=logout, body="Logout " ++ wf:user(), postback=logout }
		#button{ id=logout, body="Logout " ++ user(), postback=logout }
	), 
	[ #span{ id=upload },
		#button{ id=send, body= <<"Chat">>, postback=chat, source=[message] } ].


%%
%% Internals
%

prod() ->   [ 
		#script{src="/static/review.min.js"} 
	].


dev()  -> [ 
		[ #script{src=lists:concat(["/n2o/protocols/",X,".js"])} 
			|| X <- [bert,nitrogen] ], 
		[ #script{src=lists:concat(["/n2o/",Y,".js"])} 
			|| Y <- [bullet,n2o,ftp,utf8,validation] ] 
	].


redirect_wait() -> #dtl{}.

list() -> 
	"<iframe src=http://synrc.space/apps/"++code()++" frameborder=0 width=700 height=1250></iframe>".


code() -> 
	case wf:q(<<"code">>) of 
		undefined  -> 
			"../privacy.htm";
		Code -> 
			wf:to_list(wf:depickle(Code)) 
	end.


room() ->
	wf:info(?MODULE,"*Gethering room -> ~p~n",[wf:q(<<"room">>)]),
	Room = wf:to_list(wf:q(<<"room">>)),
	Room.

user() ->
	wf:info(?MODULE,"*Gethering user -> ~p~n",[wf:q(<<"user">>)]),
	User = wf:to_list(wf:q(<<"user">>)),
	User.
