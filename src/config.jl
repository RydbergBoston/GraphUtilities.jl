using Configurations, GraphTensorNetworks, Random

@option struct SmallGraphConfig
    name::String
end
unique_string(g::SmallGraphConfig) = g.name

@option struct RegularGraphConfig
    size::Int
    degree::Int   # for d-regular graph
    seed::Int=1
end
unique_string(g::RegularGraphConfig) = "Regular$(g.size)d$(g.degree)seed$(g.seed)"

@option struct DiagGraphConfig
    m::Int
    n::Int
    filling::Float64
    seed::Int=1
end
unique_string(g::DiagGraphConfig) = "Diag$(g.m)x$(g.n)f$(g.filling)seed$(g.seed)"

@option struct SquareGraphConfig
    m::Int
    n::Int
    filling::Float64
    seed::Int=1
end
unique_string(g::SquareGraphConfig) = "Square$(g.m)x$(g.n)f$(g.filling)seed$(g.seed)"

Configurations.type_alias(::Type{RegularGraphConfig}) = "regular"
Configurations.type_alias(::Type{DiagGraphConfig}) = "diag"
Configurations.type_alias(::Type{SquareGraphConfig}) = "square"
Configurations.type_alias(::Type{SmallGraphConfig}) = "small"

@option struct GraphProblemConfig
    problem::String
    graph::Union{RegularGraphConfig, DiagGraphConfig, SquareGraphConfig, SmallGraphConfig}
    weights::Union{Nothing, Vector} = nothing
    openvertices::Vector{Int} = Int[]
end

Base.hash(gc::GraphProblemConfig) = hash((gc.problem, gc.graph, gc.weights, gc.openvertices))
function unique_string(config::GraphProblemConfig)
    s = "$(config.problem)_$(unique_string(config.graph))"
    if config.weights !== nothing
        s *= "_w$(unique_string(config.weights))"
    end
    if !isempty(config.openvertices)
        s *= "_o$(unique_string(config.openvertices))"
    end
    return s
end
unique_string(v::AbstractVector) = string(hash(v))

const problem_list = Dict{String,Any}(
    "IndependentSet" => IndependentSet,
    "MaximalIS" => MaximalIS,
    "DominatingSet" => DominatingSet,
    "MaxCut" => MaxCut,
    "Coloring{3}" => Coloring{3},
    "Matching" => Matching,
)
parseproblem(s::String) = problem_list[s]
function parsegraph(s)
    if s isa DiagGraphConfig   # diagonal coupled square lattice
        Random.seed!(s.seed)
        random_diagonal_coupled_graph(s.m, s.n, s.filling)
    elseif s isa SquareGraphConfig
        Random.seed!(s.seed)
        random_square_lattice_graph(s.m, s.n, s.filling)
    elseif s isa RegularGraphConfig
        Random.seed!(s.seed)
        random_regular_graph(s.size, s.degree)
    elseif s isa SmallGraphConfig
        smallgraph(Symbol(s.name))
    else
        throw(ArgumentError("graph type `$(typeof(s))` is not defined!"))
    end
end

function instantiate(config::GraphProblemConfig; kwargs...)
    PT = parseproblem(config.problem)
    if PT <: Matching || PT <: Coloring
        PT(parsegraph(config.graph); openvertices=config.openvertices, kwargs...)
    else
        weights = config.weights === nothing ? NoWeight() : config.weights
        PT(parsegraph(config.graph); weights, openvertices=config.openvertices, kwargs...)
    end
end
function instantiate(config::GraphProblemConfig, code)
    PT = parseproblem(config.problem)
    if PT <: Matching || PT <: Coloring
        PT(code, parsegraph(config.graph))
    else
        weights = config.weights === nothing ? NoWeight() : config.weights
        PT(code, parsegraph(config.graph), weights)
    end
end

