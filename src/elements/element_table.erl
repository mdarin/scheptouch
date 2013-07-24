-module(element_table).
-author('Rusty Klophaus').
-include_lib("n2o/include/wf.hrl").
-compile(export_all).

render_element(Record = #table{}) -> 
  Header = case Record#table.header of
    undefined -> "";
    _ -> wf_tags:emit_tag(<<"thead">>, wf:render(Record#table.header), [])
  end,

  Footer = case Record#table.footer of
    undefined -> "";
    _ -> wf_tags:emit_tag(<<"tfoot">>, wf:render(Record#table.footer), [])
  end,
  Bodies = case Record#table.body of
    undefined -> wf_tags:emit_tag(<<"tbody">>, []);
    [] -> wf_tags:emit_tag(<<"tbody">>, []);
    Rows -> [ wf_tags:emit_tag(<<"tbody">>, wf:render(B), []) || B <- Rows]
  end,

  wf_tags:emit_tag( <<"table">>, [Header, Footer, Bodies], [
      {<<"id">>, Record#table.id},
      {<<"class">>, Record#table.class},
      {<<"style">>, Record#table.style}
  ]).