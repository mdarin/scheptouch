-module(index).
-compile(export_all).
-include_lib("kvs/include/user.hrl").
-include_lib("kvs/include/entry.hrl").
-include_lib("nitro/include/nitro.hrl").
-include_lib("n2o/include/wf.hrl").


main() ->
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

	User = user(),
	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),
	wf:info(?MODULE,"user -> ~p~n",[User]),

	wf:update(upload,#upload{id=upload}),

	SessionID = n2o_session:session_id(), 
	%wf:info(?MODULE,"session_id -> ~p~n",[SessionID]),

	% Ассоциировать процесс с пулом gproc(зарегистрировать)
	% примкнуть к ОПГ процессов по критерию "команта"
	wf:reg({topic,Room}),

	% создать парочку идиотов прислужников дьявола
	Res = wf:async("looper",fun index:loop/1),
	n2o_async:send("looper","waterline"),
	n2o_async:send("looper","my first message!"),
	%wf:info(?MODULE,"Async Process Created: ~p at Page Pid ~p~n",[Res,self()]),
	Res2 = wf:async("looper2",fun index:loop2/1),
	n2o_async:send("looper2","my second message from another!"),
	
	% получить имя бота-собеседника = Канал/Имя
	Botname = Room ++ "/" ++ "silent_bob",
	wf:info("botname -> ~p~n", [Botname]),
	case  kvs:get(user,Botname) of
%{ok,#user{id = "mile/jeremy",container = feed,
%          feed_id = "mile",prev = [],next = [],feeds = [],email = [],
%          username = "jeremy",password = [],display_name = [],
%          register_date = [],tokens = [],images = [],names = [],
%          surnames = [],birth = [],sex = [],date = [],status = [],
%          zone = [],type = []}}
	{error,not_found} ->
	% если бота в канале ещё нет, то запустим его	
		wf:info(?MODULE,"START ~p~n",[Botname]),
		wf:async(Botname,fun index:silent_Bob/1),
		kvs:put(#user{id=Botname, feed_id=Room, username="silent_bob"}),
		n2o_async:send(Botname, {init,Botname});
	_ ->
	% иначе, игнорируем этодедйствие 
		wf:info(?MODULE,"IGNORE, already started ~p~n",[Botname]),
		ok
	end,

	% получить имя бота-участника = Канал/Имя
	Botname2 = Room ++ "/" ++ "pisikak",
	wf:info("botname -> ~p~n", [Botname2]),
	case  kvs:get(user,Botname2) of
	{error,not_found} ->
	% если бота в канале ещё нет, то запустим его	
		wf:info(?MODULE,"START ~p~n",[Botname2]),
		wf:async(Botname2,fun index:pisikak/1),
		kvs:put(#user{id=Botname2, feed_id=Room, username="pisikak"}),
		n2o_async:send(Botname2, {init,Botname2});
	_ ->
	% иначе, игнорируем этодедйствие 
		wf:info(?MODULE,"IGNORE, already started ~p~n",[Botname2]),
		ok
	end,

 	% показать историю сообщений в канале
	%[wf:info(?MODULE,"**** from -> ~p  media -> ~p~n",[E#entry.from,E#entry.media])
	%	|| E <- kvs:entries(kvs:get(feed,{room,Room}),entry,10)],
	
	% подгрузить историю переписки
	[wf:send({topic,Room}, #client{data={E#entry.from,E#entry.media}})
	%[event({client,{E#entry.from, E#entry.media}}) 
		|| E <- kvs:entries(kvs:get(feed,{room,Room}),entry,10)];


event(logout) ->
	wf:info(?MODULE,"*Logout~n",[]),
	% получить данные из параметров запроса
	User = user(),
	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),
	wf:info(?MODULE,"user -> ~p~n",[User]),
	%TODO удалить всё и почистить
	wf:logout(),
	% metallica:play('turn the page'),
	wf:redirect("login.htm");


event(chat) ->
	wf:info(?MODULE,"*Chat human~n",[]),

	% получить данные из параметров запроса
	User = user(),
	wf:info(?MODULE,"user -> ~p~n",[User]),

	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),

	Message = wf:q(message),
	wf:info(?MODULE,"message -> ~p~n",[Message]),
	
	event({chat, #{room => Room, user => User, message => Message}});
	%wf:send({topic,Room},{chat, #{room => Room, user => User, message => Message}});


event({chat, #{room := Room, user := User, message := Message}}) ->
	wf:info(?MODULE,"*Chat handler~n",[]),
	Botname = Room ++ "/silent_bob",
	wf:info(?MODULE,"botname -> ~p~n", [Botname]),

	% история переписки полнится, ярчайший бред продолжается
	Id = kvs:next_id("entry",1),
	wf:info(?MODULE,"id -> ~p~n",[Id]),
	Record = #entry{
		id=Id,%kvs:next_id("entry",1),
		from=User,
		feed_id={room,Room},
		media=Message
	},
	kvs:add(Record),

	% отправить в процесс отправить боту на размышление 
	wf:send({chatbot,Botname}, {question,User,Botname,Message}),
	%n2o_async:send(Botname, {question,User,Botname,Message}),

	% опубликовать очередную светлую мысль в на первой полосе Дэйли телеграф
	wf:send({topic,Room}, #client{data={User,Message}});


event(#client{data={User,Message}}) ->
	wf:info(?MODULE,"*Show message[~p]~n",[self()]),

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
	%
	% она блокирующая в таком исполнении!
	%
	timer:sleep(3000),
	%	NOTE: wf:flush/0 should be called to redirect all updates 
	% and wire actions back to the page process
	% from its async counterpart.
	wf:flush().


% 
% молчаливый Боб – он часто курит, носит длинное пальто, у него тёмные волосы, борода, и бейсболка, 
% надетая козырьком назад. Он был воспитан в Римско-католической церкви. Своё прозвище он получил, 
% потому что почти не говорит, но когда он это делает, то произносит глубокие проницательные монологи 
% и только в соответствующих ситуациях. 
%
silent_Bob({init,Botname}) ->
	wf:info(?MODULE,"*silent Bob[~p] (!)~n",[self()]),
	% зарегистрируем процесс
	wf:reg({chatbot,Botname}),

	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 

	% сообщить о том что на мозг осела пыль
	n2o_async:send("looper2", User ++ " has joined to " ++ Room ++ " room!");


silent_Bob({question,Inquirer,Botname,Message}) ->
	wf:info(?MODULE,"*silent Bob has a conversaciton~n",[]),

	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	Reply = Inquirer ++ ", Mmmmm....",

	% имитация длительного процесса(размышелния бота, взаимеодедйтвие с хранилищем, моделью и т.п.)
	T = rand:uniform(25000) + 1000,
	timer:sleep(T),

	wf:info(?MODULE,"Q:from -> ~p m -> ~p~n", [Inquirer,Message]),
	wf:info(?MODULE,"A:to -> ~p m -> ~p~n", [Inquirer,Reply]),

	% история переписки полнится, ярчайший бред продолжается
	Id = kvs:next_id("entry",1),
	Record = #entry{
		id=Id,
		from=User,
		to=Inquirer,
		feed_id={room,Room},
		media=Reply
	},
	kvs:add(Record),

	% опубликовать 
	wf:send({topic,Room}, #client{data={User,Reply}}),
	wf:flush().


%
% Да, старичок. Пенсионная реформа не обошла стороной и его. Всё трудится.
% *Играет музыка*
% "..он молчит и ничего не делает Пи-Си-Как!"
% 
pisikak({init,Botname}) ->
	wf:info(?MODULE,"*pisikak[~p] (!)~n",[self()]),

	% зарегистрируем процесс
	wf:reg({chatbot,Botname}),

	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 

	% сообщить о том что на мозг осела пыль
	n2o_async:send("looper2", User ++ " has joined to " ++ Room ++ " room!"),
	pisikak({phrase,Botname});
	
pisikak({phrase,Botname}) ->
	wf:info(?MODULE,"*pisikak[~p] *Phrase~n",[self()]),
	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	Reply = "Pisikak, pisikak pisi pisi pisi kaakk!",

	% имитация длительного процесса(размышелния бота, взаимеодедйтвие с хранилищем, моделью и т.п.)
	T = rand:uniform(40000) + 1000,
	timer:sleep(T),

	wf:info(?MODULE,"room -> ~p~n", [Room]),
	wf:info(?MODULE,"user -> ~p~n", [User]),
	wf:info(?MODULE,"phrase -> ~p~n", [Reply]),

	% история переписки полнится, ярчайший бред продолжается
	Id = kvs:next_id("entry",1),
	Record = #entry{
		id=Id,
		from=User,
		feed_id={room,Room},
		media=Reply
	},
	kvs:add(Record),

	% опубликовать 
	%wf:send({topic,Room}, {chat, #{room => Room, user => User, message => Reply}}),
	event({chat, #{room => Room, user => User, message => Reply}}),

	wf:flush(),
	pisikak({phrase,Botname}).
	



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

	
