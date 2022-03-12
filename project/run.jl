using Comonicon
using GraphUtilities, GraphTensorNetworks, CUDA

function mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_weight, rw_weight, sc_target, prefix)
    folder = foldername(datafolder, config; create=true, prefix)
    instance = problem_instance(config;
        optimizer=TreeSA(; sc_target, sc_weight, ntrials, niters, rw_weight, nslices, βs=0.01:0.05:30),
        simplifier=MergeGreedy()
        )
    GraphUtilities.save_code(folder, instance)
end

@cast function generate_smallgraph(problem::String, name::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_regular(problem::String, size::Int;
    degree::Int=3, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    graph = RegularGraphConfig(; size, degree, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_diag(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    graph = DiagGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

@cast function generate_square(problem::String, n::Int, filling::Float64;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    graph = SquareGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
end

function load_and_compute(datafolder, config, property; prefix, cudadevice)
    folder = foldername(datafolder, config; create=false, prefix)
    instance = GraphUtilities.load_code(config, folder)
    if cudadevice >=0
        CUDA.device!(cudadevice)
    end
    res = solve(instance, property; usecuda=cudadevice>=0)[]
    save_property(folder, property, res)
end

@cast function compute_regular(problem::String, size::Int, property::String;
    degree::Int=3, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    graph = RegularGraphConfig(; size, degree, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
end

@cast function compute_diag(problem::String, n::Int, filling::Float64, property::String;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    graph = DiagGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
end

@cast function compute_square(problem::String, n::Int, filling::Float64, property::String;
    m::Int=n, seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    graph = SquareGraphConfig(; filling, m, n, seed)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
end

@cast function compute_smallgraph(problem::String, name::String, property::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
end

@main