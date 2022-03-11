using Comonicon
using GraphUtilities, GraphTensorNetworks

function mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_weight, rw_weight, sc_target, prefix)
    folder = foldername(datafolder, config; create=true, prefix)
    instance = instantiate(config;
        optimizer=TreeSA(; sc_target, sc_weight, ntrials, niters, rw_weight, nslices, βs=0.01:0.05:30),
        simplifier=MergeGreedy()
        )
    GraphUtilities.save_code(folder, instance)
end

@cast function generate_smallgraph(problem::String, name::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters=10, nslices=0, sc_target=25, sc_weight=1.0, rw_weight=1.0,  # config TreeSA
    )
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_regular(problem::String, size::Int;
    degree=3, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="",
    ntrials::Int=1, niters=10, nslices=0, sc_target=25, sc_weight=1.0, rw_weight=1.0,  # config TreeSA
    )
    graph = RegularGraphConfig(; size, degree, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_diag(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="",
    ntrials::Int=1, niters=10, nslices=0, sc_target=25, sc_weight=1.0, rw_weight=1.0,  # config TreeSA
    )
    graph = DiagGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_square(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="",
    ntrials::Int=1, niters=10, nslices=0, sc_target=25, sc_weight=1.0, rw_weight=1.0,  # config TreeSA
    )
    graph = SquareGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

function load_and_compute(datafolder, config, property; prefix)
    folder = foldername(datafolder, config; create=false, prefix)
    instance = GraphUtilities.load_code(config, folder)
    res = solve(instance, property)[]
    save_property(folder, property, res)
end

@cast function compute_regular(problem::String, size::Int, property::String;
    degree=3, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = RegularGraphConfig(; size, degree, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix)
end

@cast function compute_diag(problem::String, n::Int, filling::Float64, property;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = DiagGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix)
end

@cast function compute_square(problem::String, n::Int, filling::Float64, property;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = SquareGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix)
end

@cast function compute_smallgraph(problem::String, name::String, property::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder="data", prefix="")
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix)
end

@main