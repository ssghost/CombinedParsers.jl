"""
Top level parser supporting regular expression features
captures, backreferences and subroutines.
Collects subroutines in field `subroutines::Vector` and 
indices of named capture groups in field `names::Dict`.

!!! note
    implicitly called in [`match`](@ref)
See also [`Backreference`](@ref), [`Capture`](@ref), [`Subroutine`](@ref)
"""
@auto_hash_equals struct ParserWithCaptures{P,S,T} <: WrappedParser{P,S,T}
    parser::P
    subroutines::Vector{CombinedParser} ## todo: rename subroutines
    names::Dict{Symbol,Vector{Int}}
    ParserWithCaptures(parser,captures,names) =
        new{typeof(parser),state_type(parser),result_type(parser)}(parser,captures,names)
end
function print_constructor(io::IO, x::ParserWithCaptures)
    print_constructor(io,x.parser)
    print(io, " |> regular expression combinator",
          ( length(x.subroutines)>0 ? " with $(length(x.subroutines)) capturing groups" : "" ) )
end
"""
    _iterate(p::ParserWithCaptures, sequence::SequenceWithCaptures,a...)

`Base.empty!(sequence)` before iteration.
"""
function _iterate(p::ParserWithCaptures, sequence::SequenceWithCaptures,a...)
    Base.empty!(sequence)
    _iterate(p.parser, sequence, a...)
end
"""
    ParserWithCaptures(x)

Return `ParserWithCaptures` if captures are used, `x` otherwise.
Two passes of `deepmap_parser(indexed_captures_,...)` are used 
(1. to assign `Capture` indices and 
 2. to use index number for `Backreference` and `Subroutine`).

See also [`indexed_captures_`](@ref)
"""
ParserWithCaptures(x) =
    let cs = ParserWithCaptures(x,CombinedParser[],Dict{Symbol,Int}())
        pass1 = ParserWithCaptures(deepmap_parser(indexed_captures_,NoDict(),x,cs,false),cs.subroutines,cs.names)
        r = ParserWithCaptures(deepmap_parser(indexed_captures_,NoDict(),pass1.parser,pass1,false),pass1.subroutines,pass1.names)
        isempty(r.subroutines) ? r.parser : r
    end

import ..CombinedParsers: MatchesIterator
function MatchesIterator(p::ParserWithCaptures,s::AbstractString,idx=1)
    MatchesIterator(p, SequenceWithCaptures(s,p), idx)
end

# _iterate(parser::ParserWithCaptures, sequence::AbstractString, till, next_i, after, state::Nothing) =
#     _iterate(parser, sequence, till, next_i, next_i, state)

SequenceWithCaptures(x,cs::CombinedParser) = x
function SequenceWithCaptures(x,cs::ParserWithCaptures)
    ## @show S=typeof(x)
    SequenceWithCaptures(
        x,cs.subroutines,
        Vector{String}[ String[] for c in cs.subroutines ],
        cs.names,
        nothing)
end


set_options(set::UInt32,unset::UInt32,parser::ParserWithCaptures) =
    ParserWithCaptures(set_options(set,unset,parser.parser),
                       CombinedParser[ set_options(set,unset,p) for p in parser.subroutines],
                       parser.names)

function deepmap_parser(f::Function,mem::AbstractDict,x::ParserWithCaptures,a...;kw...)
    ParserWithCaptures(deepmap_parser(f,mem,x.parser,a...;kw...),
                       [ deepmap_parser(f,mem,p,a...;kw...) for p in x.subroutines ],
                       x.names)
end

ParserWithCaptures(x::ParserWithCaptures) = x

"""
https://www.pcre.org/original/doc/html/pcrepattern.html#SEC16
"""
function subroutine_index_reset(context::ParserWithCaptures,x::Capture)
    if x.index<0
        index = length(context.subroutines)+1
        push!(context.subroutines,Capture(x,index))
        if x.name !== nothing
            push!(get!(context.names,x.name) do
                  Int[]
                  end,
                  index)
        end
        index, true
    else
        x.index, false
    end
end

import ..CombinedParsers: JoinSubstring, Transformation
JoinSubstring(x::ParserWithCaptures) =
    ParserWithCaptures(JoinSubstring(x.parser),x.subroutines,x.names)
Transformation{T}(t,x::ParserWithCaptures) where T =
    ParserWithCaptures(Transformation{T}(t,x.parser),x.subroutines,x.names)


function deepmap_parser(::typeof(indexed_captures_),mem::AbstractDict,x::Backreference,context,a...)
    get!(mem,x) do
        idx = capture_index(x.name,Symbol(""),x.index,context)
        if idx < 1 || idx>lastindex(context.subroutines)
            x.name === nothing ? x.fallback() : x
        else
            Backreference(x.fallback,x.name, idx)
        end
    end
end
function deepmap_parser(::typeof(indexed_captures_),mem::AbstractDict,x::Subroutine,context,a...)
    get!(mem,x) do
        index = capture_index(x.name,x.delta,x.index, context)
        if index <= 0 || index>length(context.subroutines)
            Subroutine{Any,Any}(x.name,Symbol(""),index)
        else
            sr = context.subroutines[index]
            Subroutine{state_type(sr),result_type(sr)}(
                x.name,Symbol(""),index)
        end
    end
end

"""
    deepmap_parser(f::typeof(indexed_captures_),mem::AbstractDict,x::DupSubpatternNumbers,context,reset_index)

set `reset_index===true'.
"""
function deepmap_parser(f::typeof(indexed_captures_),mem::AbstractDict,x::DupSubpatternNumbers,context,reset_index)
    get!(mem,x) do
        DupSubpatternNumbers(deepmap_parser(
            indexed_captures_,mem,
            x.parser,context,
            true))
    end
end

"""
    deepmap_parser(::typeof(indexed_captures_),mem::AbstractDict,x::Either,context,reset_index)

Method dispatch, resetting `lastindex(context.subroutines)` if `reset_index===true'.
"""
deepmap_parser(::typeof(indexed_captures_),mem::AbstractDict,x::Either{<:Tuple},context,reset_index) =
    indexed_captures_(mem,x,context,reset_index)
deepmap_parser(::typeof(indexed_captures_),mem::AbstractDict,x::Either{<:Vector},context,reset_index) =
    indexed_captures_(mem,x,context,reset_index)
function indexed_captures_(mem::AbstractDict,x::Either,context,reset_index)
    if reset_index
        idx = lastindex(context.subroutines)
        branches = Any[]
        for p in reverse(x.options) ## keep first for subroutines
            while lastindex(context.subroutines)>idx
                pop!(context.subroutines)
            end
            push!(branches,deepmap_parser(
                indexed_captures_,
                mem,
                p,context,false))
        end
        Either{result_type(x)}(tuple( branches... ))
    else
        Either{result_type(x)}(
            tuple( (deepmap_parser(indexed_captures_,mem,p,context,false) for p in x.options )...))
    end
end

"""
    deepmap_parser(f::typeof(indexed_captures_),mem::AbstractDict,x::Capture,context,a...)

Map the capture my setting `index` to  `_nextind(context,x)`.

Registers result in `context.subroutines` if no previous subroutine with the same index exists
(see also [`DupSubpatternNumbers`](@ref)).
"""
function deepmap_parser(f::typeof(indexed_captures_),mem::AbstractDict,x::Capture,context,a...)
    get!(mem,x) do
        index,reset=subroutine_index_reset(context,x)
        r = Capture(
            x.name,
            deepmap_parser(indexed_captures_,mem,x.parser,context,a...),
            index
        )
        reset && ( context.subroutines[index] = r )
        r
    end
end

##Base.getindex(x::ParserWithCaptures, i) = ParserWithCaptures(getindex(i,x)

"For use in ParserWithCaptures to enforce different indices for identical captures."
struct NoDict{K,V} <: AbstractDict{K,V} end
NoDict() = NoDict{Any,Any}()

import Base: get!
Base.get!(f::Function,d::NoDict,k) = f()
