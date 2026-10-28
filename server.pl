% Ejecutar: swipl server.pl   ->   http://localhost:8080
:- set_prolog_flag(encoding, utf8).

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/http_files)).

:- consult('metrocdmx.pl').   

:- http_handler('/', http_reply_file('web/index.html', []), []).
:- http_handler('/api/estaciones', api_estaciones, []).
:- http_handler('/api/viaje', api_viaje, []).

% GET /api/estaciones -> lista de estaciones para el formulario
api_estaciones(_) :-
    findall(E, (arista(E,_,_,_) ; arista(_,E,_,_)), L0),
    sort(L0, L),
    reply_json_dict(_{estaciones: L}).

% GET /api/viaje?origen=X&destino=Y
api_viaje(Request) :-
    http_parameters(Request, [origen(O, [atom]), destino(D, [atom])]),
    (   catch(mejor_viaje(O, D, Mejor), _, fail)
    ->  viaje_dict(Mejor, MejorDict),
        findall(Alt,
                ( lineas_de(O, Ls), member(L, Ls),
                  catch(mejor_camino(O, D, L, Par), _, fail),
                  viaje_dict(Par, Alt) ),
                Alts0),
        sort(Alts0, Alts),
        reply_json_dict(_{ok: true, origen: O, destino: D,
                          mejor: MejorDict, alternativas: Alts})
    ;   reply_json_dict(_{ok: false,
                          mensaje: "No se encontró ruta o alguna estación no existe."})
    ).

% Convierte Costo-RutaInvertida en un dict con ruta y tramos (con su línea)
viaje_dict(Costo-Ruta0, _{costo: Costo, ruta: Ruta, tramos: Tramos}) :-
    reverse(Ruta0, Ruta),
    tramos(Ruta, Tramos).

tramos([], []).
tramos([_], []) :- !.
tramos([A,B|T], [_{de: A, a: B, linea: L}|R]) :-
    conexion(A, B, L, _), !,
    tramos([B|T], R).

% Arranque (PORT en la nube, 8080 en local)
:- initialization(main, main).

main :-
    (   getenv('PORT', P) -> atom_number(P, Port) ; Port = 8080 ),
    http_server(http_dispatch, [port(Port)]),
    format("Servidor en http://localhost:~w~n", [Port]),
    thread_get_message(_).