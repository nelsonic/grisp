% @doc GRiSP I2C API.
-module(grisp_ni2c).

-include("grisp_nif.hrl").

% API
-export([buses/0]).
-export([open/1]).
-export([detect/1]).
-export([read/4]).
-export([write/4]).
-export([transfer/2]).

% Callbacks
-export([on_load/0]).
-on_load(on_load/0).

%--- Types ---------------------------------------------------------------------

-type bus_name() :: atom().
-type bus_path() :: iolist().
-opaque bus() :: reference().
-type addr() :: 1..127.
-type length() :: non_neg_integer().
-type message() :: {
    Type :: read | write,
    ChipAddr :: addr(),
    Flags :: non_neg_integer(),
    Payload :: iolist() | length()
}.

-export_type([bus/0]).
-export_type([addr/0]).
-export_type([length/0]).
-export_type([message/0]).

%--- API -----------------------------------------------------------------------

% @doc List I2C buses.
-spec buses() -> #{bus_name() => #{name => bus_name(), path => bus_path()}}.
buses() ->
    #{
        i2c0 => #{name => i2c0, path => <<"/dev/i2c-0">>},
        i2c1 => #{name => i2c1, path => <<"/dev/i2c-1">>}
    }.

% @doc Open an I2C bus device by name.
%
% @see buses/0
-spec open(bus_name()) -> bus().
open(Name) ->
    #{path := Path} = maps:get(Name, buses()),
    i2c_open_nif(null(Path)).

% @doc Detect I2C devices on a bus.
%
% Returns the address of each found device.
%
% === Example ===
% ```
% 1> [io_lib:format("0x~.16B", [Addr]) || Addr <- grisp_ni2c:detect(Bus1)].
% ["0x18","0x36","0x37","0x52","0x57","0x5A","0x5F"]
% '''
-spec detect(bus()) -> [addr()].
detect(Bus) ->
    lists:reverse(lists:foldl(fun(ChipAddr, Detected) ->
        case grisp_ni2c:transfer(Bus, [{write, ChipAddr, 0, <<>>}]) of
            {error, ioctl_failed, _} -> Detected;
            [ok] -> [ChipAddr|Detected]
        end
    end, [], lists:seq(1, 127))).

% @doc Read from a register on an I2C chip.
-spec read(bus(), addr(), non_neg_integer(), length()) -> binary().
read(Bus, ChipAddr, RegAddr, Length) ->
    [ok, Resp] = transfer(Bus, [
        {write, ChipAddr, 0, <<RegAddr>>},
        {read, ChipAddr, 1, Length}
    ]),
    Resp.

% @doc Write to a register on an I2C chip.
write(Bus, ChipAddr, RegAddr, Data) ->
    [ok] = transfer(Bus, [{write, ChipAddr, 0, <<RegAddr, Data/binary>>}]),
    ok.

% @doc Transfer I2C messages on a bus.
-spec transfer(bus(), [message()]) -> [ok | binary()].
transfer(Bus, Messages) -> i2c_transfer_nif(Bus, Messages).

%--- Callbacks -----------------------------------------------------------------

on_load() -> ok = erlang:load_nif(atom_to_list(?MODULE), 0).

%--- Internal ------------------------------------------------------------------

i2c_open_nif(_Bus) -> ?NIF_STUB.

i2c_transfer_nif(_Bus, _Messages) -> ?NIF_STUB.

null(Bin) -> [Bin, 0].
