export MatchState
"""
State object for a match that is defined by the triple `parser, sequence, position`.

!!! note:
    Performance tip: [`Atomic`](@ref) is masking the state of its wrapped parser with `MatchState`.
    This simplifies the state
"""
struct MatchState end
Base.show(io::IO, ::MatchState) = print(io,"∘")

"""
State object representing ncodeunits explicitely with state of match for `prevind`, `nextind` to improve performance.
    `nc::Int` and `state::S`.

See also [`MatchState`](@ref), [`prevind`](@ref), [`nextind`](@ref).

!!! note:
    `nc` as type parameter faster but slow compilation.
"""
struct NCodeunitsState{S}
    nc::Int
    state::S
end
@inline _leftof(str,i,parser::CombinedParser,x::NCodeunitsState) = i-x.nc
@inline _rightof(str,i,parser::CombinedParser,x::NCodeunitsState) = i+x.nc
"""
    NCodeunitsState(posi::Int,after::Int,state)
    NCodeunitsState{S}(posi::Int,after::Int,state)

returns `(tuple_pos, NCodeunitsState(after-posi,state))`.

!!! note:
    rename
"""
NCodeunitsState(posi::Int,after::Int,state) =
    after, NCodeunitsState(after-posi,state)
@inline NCodeunitsState{S}(posi::Int,after::Int,state) where S =
    after, NCodeunitsState{S}(after-posi,state)



"""
    tuple_pos(pos_state::Tuple)

[`_iterate`](@ref) returns a tuple `pos_state` or nothing, and 
`pos_state[1]` is position after match.
"""
@inline tuple_pos(pos_state::Tuple, default...) = pos_state[1]
@inline tuple_pos(pos_state::Nothing, default) = default

"""
    tuple_state(pos_state::Tuple)

[`_iterate`](@ref) returns a tuple `pos_state` or nothing, and
`pos_state[2]` is the state of match.
"""
@inline tuple_state(pos_state::Tuple) = pos_state[2]
@inline tuple_state(pos_state::Nothing) = nothing
