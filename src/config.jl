using Configurations, GraphTensorNetworks, Random
using UnitDiskMapping

abstract type AbstractGraphConfig end

@option struct SmallGraphConfig <: AbstractGraphConfig
    name::String
end
unique_string(g::SmallGraphConfig) = g.name

@option struct RegularGraphConfig <: AbstractGraphConfig
    size::Int
    degree::Int   # for d-regular graph
    seed::Int=1
end
unique_string(g::RegularGraphConfig) = "Regular$(g.size)d$(g.degree)seed$(g.seed)"

@option struct MappedRegularGraphConfig <: AbstractGraphConfig
    size::Int
    degree::Int   # for d-regular graph
    seed::Int=1
end
unique_string(g::MappedRegularGraphConfig) = "MappedRegular$(g.size)d$(g.degree)seed$(g.seed)"

@option struct MISProjectGraphConfig <: AbstractGraphConfig
    n::Int
    index::Int=1
end
unique_string(g::MISProjectGraphConfig) = "MISProject$(g.n)index$(g.index)"

@option struct DiagGraphConfig <: AbstractGraphConfig
    m::Int
    n::Int
    filling::Float64
    seed::Int=1
end
unique_string(g::DiagGraphConfig) = "Diag$(g.m)x$(g.n)f$(g.filling)seed$(g.seed)"

@option struct SquareGraphConfig <: AbstractGraphConfig
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
    graph::AbstractGraphConfig
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

const problem_dict = Dict{String,Any}(
    "IndependentSet" => IndependentSet,
    "MaximalIS" => MaximalIS,
    "DominatingSet" => DominatingSet,
    "MaxCut" => MaxCut,
    "Coloring{3}" => Coloring{3},
    "Matching" => Matching,
)
parseproblem(s::String) = problem_dict[s]
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
    elseif s isa MISProjectGraphConfig
        folder = joinpath(homedir(), ".julia/dev/TropicalMIS", "project", "data")
        fname = joinpath(folder, "mis_degeneracy2_L$(s.n).dat")
        mask = Matrix{Bool}(reshape(readdlm(fname)[s.index+1,5:end], s.n, s.n))
        diagonal_coupled_graph(mask)
    elseif s isa SmallGraphConfig
        smallgraph(Symbol(s.name))
    elseif s isa MappedRegularGraphConfig
        Random.seed!(s.seed)
        graph = random_regular_graph(s.size, s.degree)
        if nv(graph) <= 50
            res = map_graph(graph)
        else
            res = map_graph(graph; vertex_order=Greedy(; nrepeat=100))
        end
        SimpleGraph(res.grid_graph)
    else
        throw(ArgumentError("graph type `$(typeof(s))` is not defined!"))
    end
end

function problem_instance(config::GraphProblemConfig; kwargs...)
    PT = parseproblem(config.problem)
    weights = config.weights === nothing ? NoWeight() : config.weights
    PT(parsegraph(config.graph); weights, openvertices=config.openvertices, kwargs...)
end
function problem_instance(config::GraphProblemConfig, code)
    PT = parseproblem(config.problem)
    weights = config.weights === nothing ? NoWeight() : config.weights
    PT(code, parsegraph(config.graph), weights)
end

unique_string(::SingleConfigMax{K}) where K = "SingleConfigMax$K"
unique_string(::SingleConfigMin{K}) where K = "SingleConfigMin$K"
unique_string(::SizeMax{K}) where K = "SizeMax$K"
unique_string(::SizeMin{K}) where K = "SizeMin$K"
unique_string(::ConfigsMax{K,B,true}) where {K,B} = "ConfigsMaxTree$K"
unique_string(::ConfigsMin{K,B,true}) where {K,B} = "ConfigsMinTree$K"
unique_string(::ConfigsMax{K,B,false}) where {K,B} = "ConfigsMax$K"
unique_string(::ConfigsMin{K,B,false}) where {K,B} = "ConfigsMin$K"
unique_string(::CountingMax{K}) where K = "CountingMax$K"
unique_string(::CountingMin{K}) where K = "CountingMin$K"
unique_string(::ConfigsAll{true}) = "ConfigsAllTree"
unique_string(::ConfigsAll{false}) = "ConfigsAll"
unique_string(::CountingAll) = "CountingAll"
unique_string(::GraphPolynomial) = "GraphPolynomial"

property_dict = Dict{String,Any}(
    "SizeMax" => SizeMax,
    "SizeMin" => SizeMin,
    "SingleConfigMax" => SingleConfigMax,
    "SingleConfigMin" => SingleConfigMin,
    "ConfigsMax" => ConfigsMax,
    "ConfigsMin" => ConfigsMin,
    "ConfigsAll" => ConfigsAll,
    "GraphPolynomial" => GraphPolynomial,
    "CountingMax" => CountingMax,
    "CountingMin" => CountingMin,
    "CountingAll" => CountingAll,
)

function parseproperty(property::String)
    m1 = match(r"(\w+)(\d+)", property)
    if m1 === nothing
        m2 = match(r"(\w+)Tree", property)
        if m2 === nothing
            return property_dict[property]()
        else
            return property_dict[m2[1]](; tree_storage=true)
        end
    else
        m2 = match(r"(\w+)Tree", m1[1])
        K = parse(Int, m1[2])
        if m2 === nothing
            return property_dict[m1[1]](K)
        else
            return property_dict[m2[1]](K; tree_storage=true)
        end
    end
end
