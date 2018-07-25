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
	Fullname = Room ++ "/" ++ User,
	% запонить пользователя
	kvs:put(#user{id=Fullname, feed_id=Room, username=User}),
	wf:info(?MODULE,"room -> ~p~n",[Room]),
	wf:info(?MODULE,"user -> ~p~n",[User]),
	wf:info(?MODULE,"fullname -> ~p~n",[Fullname]),
	wf:update(upload,#upload{id=upload}),
	SessionID = n2o_session:session_id(), 
	% примкнуть к ОПГ процессов по критерию "команта"
	wf:reg({topic,Room}),
	% создать парочку идиотов прислужников дьявола
	Res = wf:async("looper",fun index:loop/1),
	n2o_async:send("looper","waterline"),
	%wf:info(?MODULE,"Async Process Created: ~p at Page Pid ~p~n",[Res,self()]),
	Res2 = wf:async("looper2",fun index:loop2/1),
	n2o_async:send("looper2","yet anohter waterline"),
	% получить имя бота-собеседника = Канал/Имя
	Botname = Room ++ "/" ++ "silent_bob",
	wf:info("botname -> ~p~n", [Botname]),
	case  kvs:get(user,Botname) of
		{error,not_found} ->
		% если бота в канале ещё нет, то запустим его	
			wf:info(?MODULE,"START ~p~n",[Botname]),
			R1 = wf:async(Botname, fun index:silent_Bob/1),
			wf:info(?MODULE,"res1 -> ~p~n",[R1]),
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
				R2 = wf:async(Botname2, fun index:pisikak/1),
				wf:info(?MODULE,"res2 -> ~p~n",[R2]),
				kvs:put(#user{id=Botname2, feed_id=Room, username="pisikak"}),
				n2o_async:send(Botname2, {init,Botname2});
			_ ->
			% иначе, игнорируем этодедйствие 
				wf:info(?MODULE,"IGNORE, already started ~p~n",[Botname2]),
				ok 
	end,
	% подгрузить историю переписки
	[event({client,{E#entry.from, E#entry.media}}) 
		|| E <- kvs:entries(kvs:get(feed,{room,Room}),entry,10)];


event(terminate) ->
	wf:info(?MODULE,"*Teriminate~n",[]);


event(logout) ->
	wf:info(?MODULE,"*Logout~n",[]),
	% получить данные из параметров запроса
	User = user(),
	Room = room(),
	wf:info(?MODULE,"room -> ~p~n",[Room]),
	wf:info(?MODULE,"user -> ~p~n",[User]),
	% сжечь карточку выздоравливающего пациента
	Fullname = Room ++ "/" ++ User,
	kvs:delete(user,Fullname),
	% сколько там ещё в палате?
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
	end,
	wf:logout(),
	% metallica:play('turn the page'),
	wf:redirect("login.htm");


event(chat) ->
	wf:info(?MODULE,"*Chat human~n",[]),
	% получить данные из параметров запроса
	User = user(),
	Room = room(),
	Message = wf:q(message),
	wf:info(?MODULE,"room -> ~p~n",[Room]),
	wf:info(?MODULE,"user -> ~p~n",[User]),
	wf:info(?MODULE,"message -> ~p~n",[Message]),
	event(#{room => Room, user => User, message => Message});


event(#{room := Room, user := User, message := Message}) ->
	wf:info(?MODULE,"*Chat handler~n",[]),
	Botname = Room ++ "/silent_bob",
	wf:info(?MODULE,"botname -> ~p~n", [Botname]),
	% история переписки полнится, ярчайший бред продолжается
	Id = kvs:next_id("entry",1),
	Record = #entry{
		id=Id,
		from=User,
		feed_id={room,Room},
		media=Message
	},
	kvs:add(Record),
	% отправить боту на размышление 
	wf:send({chatbot,Botname}, #{type => question, from => User, to => Botname, message => Message}),
	% опубликовать очередную светлую мысль в на первой полосе Дэйли телеграф
	%event(#client{data={User,Message}});
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

%
% Когда речь заходит о ботах, вспоминатся одно из произведений классики киберпанка...
% <...>
% – Что значит «ЯМ»?
%
% Каждый из нас уже отвечал на этот вопрос тысячу раз, но Бенни давно забыл об этом. Ответил Горристер:
%
% – Сначала это значило Ядерный Манипулятор, потом, когда его создатели почувствовали опасность, 
% – Ярмо Машины, Ярость Маньяка, Ядрена Мать... но уже ничего нельзя было изменить, и, наконец, 
% сам он, хвастаясь эрудицией, назвал себя ЯМ, что значило... cogito ergo sum... 
% Я мыслю, следовательно, существую.
%
% <...>
% И ЯМ сказал, очень вежливо, написав на столике из стали неоновым светом буквы:
%
% – НЕНАВИЖУ. ПОЗВОЛЬТЕ МНЕ СКАЗАТЬ ВАМ, НАСКОЛЬКО Я ВОЗНЕНАВИДЕЛ ВАС С ТЕХ ПОР, КАК Я НАЧАЛ ЖИТЬ.
%  МОЯ СИСТЕМА СОСТОИТ ИЗ 38744 МИЛЛИОНОВ МИЛЬ ПЕЧАТНЫХ ПЛАТ НА МОЛЕКУЛЯРНОЙ ОСНОВЕ. ЕСЛИ СЛОВО 
% «НЕНАВИЖУ» ВЫГРАВИРОВАТЬ НА КАЖДОМ НАНОАНГСТРЕМЕ ЭТИХ СОТЕН МИЛЛИОНОВ МИЛЬ, ТО ЭТО НЕ ВЫРАЗИТ И 
% БИЛЛИОНОЙ ДОЛИ ТОЙ НЕНАВИСТИ, КОТОРУЮ ИСПЫТЫВАЮ Я В ДАННЫЙ МИКРОМИГ ПО ОТНОШЕНИЮ К ВАМ. НЕНАВИЖУ. 
% НЕНАВИЖУ.
% Он делал это, чтобы раскрыть мне глаза на причины, объясняющие, почему он так поступает с нами, 
% почему он сохранил нас пятерых для своих опытов.

% Мы научили его чувствовать. Мы сделали это нечаянно, и все-таки... Он попал в ловушку. 
% Он был машиной. Мы предоставили ему возможность думать, но не указали, что делать с результатами 
% мыслительных процессов. В гневе, в бешенстве он убил почти всех из нас, но высвободиться из ловушки 
% не мог.

% И чтобы нашему боту не было скучно и он, как ЯМ не придумал уничтожать человечество, 
% создадим не одного, а сразу двух, пусть общаются, развлекая друг дружку! 


% 
% молчаливый Боб – он часто курит, носит длинное пальто, у него тёмные волосы, борода, и бейсболка, 
% надетая козырьком назад. Он был воспитан в Римско-католической церкви. Своё прозвище он получил, 
% потому что почти не говорит, но когда он это делает, то произносит глубокие проницательные монологи 
% и только в соответствующих ситуациях. 
%
silent_Bob({stop,Botname}) -> 
	wf:info(?MODULE,"*silent Bob[~p] *Exit~n",[self()]),
	wf:info(?MODULE,"*silent Bob is slowing down gracefully now...~n",[]),
	n2o_async:stop(Botname),
	% освободить имя
	wf:unreg({chatbot,Botname}),
	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	% удалить канал
	lists:foreach(
		fun({feed,{room,Room},_,_,_,_}) -> kvs:delete(feed,{room,Room}); 
				(_) -> ok
	end, kvs:all(feed)),
	ok;


silent_Bob({init,Botname}) ->
	wf:info(?MODULE,"*silent Bob[~p] (!)~n",[self()]),
	% зарегистрируем процесс
	wf:reg({chatbot,Botname}),
	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	% сообщить о том что на мозг осела пыль
	n2o_async:send("looper2", User ++ " has joined to " ++ Room ++ " room!");


silent_Bob(#{type := question, from := Inquirer, to := Botname, message := Message}) ->
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
pisikak({stop,Botname}) -> 
	wf:info(?MODULE,"*pisikak[~p] *Exit~n",[self()]),
	wf:info(?MODULE,"*pisikak is slowing down gracefully now...~n",[]),
	n2o_async:stop(Botname),
	% освободить имя
	wf:unreg({chatbot,Botname}),
	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	% удалить канал
	lists:foreach(
		fun({feed,{room,Room},_,_,_,_}) -> kvs:delete(feed,{room,Room}); 
				(_) -> ok
	end, kvs:all(feed)),
	ok;


pisikak({init,Botname}) ->
	wf:info(?MODULE,"*pisikak[~p] (!)~n",[self()]),
	% зарегистрируем процесс
	wf:reg({chatbot,Botname}),
	User = filename:basename(Botname),
	Room = filename:dirname(Botname), 
	% сообщить о том что на мозг осела пыль
	n2o_async:send("looper2", User ++ " has joined to " ++ Room ++ " room!"),
	wf:send({chatbot,Botname}, {phrase,Botname});
	

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
	% опубликовать творчество этого периода
	event(#{room => Room, user => User, message => Reply}),
	% и вновь пуститься в рамышления!
	wf:send({chatbot,Botname}, {phrase,Botname}),
	wf:flush().


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

	
