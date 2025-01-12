
export caseless
caseless(x) = MappingParser(lowercase, deepmap_parser(lowercase,parser(x)))

export MappingParser
@auto_hash_equals struct MappingParser{P,S,T,F<:Function} <: WrappedParser{P,S,T}
    parser::P
    f::F
    function MappingParser(f::F,p::P) where {F<:Function,P}
        new{P,state_type(p),result_type(p),F}(p,f)
    end
end

@inline function _iterate(parser::M, sequence::String, till, posi,after,state) where {M<:MappingParser}
    # @warn "for memoizing, wrap sequence in WithMemory"
    _iterate(parser.parser, MappedChars(parser.f,sequence), till,posi,after,state)
end

reversed(x::MappingParser) = MappingParser(x.f,x.parser)

deepmap_parser(f::Function,mem::AbstractDict,x::MappingParser,a...;kw...) =
    get!(mem,x) do
        ## construct replacement, e.g. if P <: WrappedParser
        MappingParser(x.f,deepmap_parser(f,mem,x.parser,a...;kw...))
    end

export MappedChars
"""
    MappedChars(f::Function,x) <: AbstractString

String implementation lazily transforming characters.
Used for fast caseless matching.

```@meta
DocTestFilters = r"[0-9.]+ .s.*"
```

```jldoctest
julia> p = caseless("AlsO")
🗄  |> MappingParser
├─ also
└─ lowercase
::String

julia> p("also")
"also"

julia> using BenchmarkTools;

julia> @btime match(p,"also");
  51.983 ns (2 allocations: 176 bytes)

julia> p = parser("also"); @btime match(p,"also");
  44.759 ns (2 allocations: 176 bytes)

```
"""
struct MappedChars{S,M<:Function} <: AbstractString
    x::S
    f::M
    function MappedChars(mem::M,x::S) where {S,M<:Function}
        new{S,M}(x,mem)
    end
end
function MappedChars(x)
    MappedChars(x,Dict())
end
Base.show(io::IO, x::MappedChars) =
    print(io,x.x)

@inline Base.@propagate_inbounds Base.getindex(x::MappedChars,i::Integer) =
    x.f(getindex(x.x,i))
@inline Base.@propagate_inbounds Base.iterate(x::MappedChars{<:AbstractString}) =
    let i=iterate(x.x)
        i===nothing && return nothing
        x.f(tuple_pos(i)), tuple_state(i)
    end
@inline Base.@propagate_inbounds Base.iterate(x::MappedChars{<:AbstractString},i::Integer) =
    let j=iterate(x.x,i)
        j===nothing && return nothing
        x.f(tuple_pos(j)), tuple_state(j)
    end

@inline Base.@propagate_inbounds Base.SubString(x::MappedChars,start::Int,stop::Int) = SubString(x.x,start,stop)
@inline Base.@propagate_inbounds Base.length(x::MappedChars) = length(x.x)
@inline Base.@propagate_inbounds Base.lastindex(x::MappedChars) = lastindex(x.x)
@inline Base.@propagate_inbounds Base.firstindex(x::MappedChars) = firstindex(x.x)
@inline Base.@propagate_inbounds _prevind(x::MappedChars,i::Int,n::Int) = _prevind(x.x,i,n)
@inline Base.@propagate_inbounds _nextind(x::MappedChars,i::Int,n::Int) = _nextind(x.x,i,n)
@inline Base.@propagate_inbounds _prevind(x::MappedChars,i::Int) = _prevind(x.x,i)
@inline Base.@propagate_inbounds _nextind(x::MappedChars,i::Int) = _nextind(x.x,i)
@inline Base.@propagate_inbounds Base.ncodeunits(x::MappedChars) = ncodeunits(x.x)
