using Comonicon
using GraphUtilities, GraphTensorNetworks

@enum GraphProblemTypes IndependentSet

@cast function generate_smallgraph(problem::String, name::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="")
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    foldername(datafolder, config; create=true, prefix)
end

@cast function generate_regular(problem::String, size::Int;
    degree=3, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = RegularGraphConfig(; size, degree, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    foldername(datafolder, config; create=true, prefix)
end

@cast function generate_diag(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = DiagGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    foldername(datafolder, config; create=true, prefix)
end

@cast function generate_square(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = SquareGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    foldername(datafolder, config; create=true, prefix)
end

@cast function generate_fromtemplate(problem::String, name::Symbol, weights=NoWeight(), datafolder="data", prefix="$(graphname)_n$(n)_seed$(seed)_")
    g = generate_graph(graphname, size, seed)
    config = GraphProblemConfig(eval(Meta.parse(problem)), g; weights, openvertices=())
    foldername(datafolder, config; create=true, prefix)
end

@cast function compute()
end

@main