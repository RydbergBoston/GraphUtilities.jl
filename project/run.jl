using Comonicon
using GraphUtilities, GraphTensorNetworks, CUDA
using DelimitedFiles

########################### GENERATE ###################################
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
    sizestop::Int=size, sizestep::Int=1,
    degree::Int=3, seed::Int=1, seedstop::Int=seed,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = RegularGraphConfig(; size=sz, degree, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
    end
end

@cast function generate_diag(problem::String, size::Int, filling::Float64;
    sizestop::Int=size, sizestep::Int=1,
    seed::Int=1, seedstop::Int=seed,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = DiagGraphConfig(; filling, m=sz, n=sz, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
    end
end

@cast function generate_square(problem::String, size::Int, filling::Float64;
    sizestop::Int=size, sizestep::Int=1,
    seed::Int=1, seedstop::Int=seed,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = SquareGraphConfig(; filling, m=sz, n=sz, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
    end
end

function load_and_compute(datafolder, config, property; prefix, cudadevice)
    folder = foldername(datafolder, config; create=false, prefix)
    instance = GraphUtilities.load_code(config, folder)
    println("time, space, RW complexitys are $(timespacereadwrite_complexity(instance))")
    if cudadevice >=0
        CUDA.device!(cudadevice)
    end
    res = solve(instance, property; usecuda=cudadevice>=0)[]
    save_property(folder, property, res)
end

########################### COMPUTE ###################################
@cast function compute_regular(problem::String, size::Int, property::String;
    sizestop::Int=size, sizestep::Int=1,
    degree::Int=3, seed::Int=1, seedstop::Int=seed,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = RegularGraphConfig(; size=sz, degree, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
    end
end

@cast function compute_diag(problem::String, size::Int, filling::Float64, property::String;
    sizestop::Int=size, sizestep::Int=1,
    seed::Int=1, seedstop::Int=seed,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = DiagGraphConfig(; filling, m=sz, n=sz, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
    end
end

@cast function compute_square(problem::String, size::Int, filling::Float64, property::String;
    sizestop::Int=size, sizestep::Int=1,
    seed::Int=1,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = SquareGraphConfig(; filling, m=sz, n=sz, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
    end
end

@cast function compute_smallgraph(problem::String, name::String, property::String;
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    graph = SmallGraphConfig(name)
    config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
    load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
end

########################### OGP ###################################

@cast function ogp_diag(size::Int;
    sizestop::Int=size, sizestep::Int=1,
    seed::Int=1, seedstop::Int=seed,
    alpha::Float64=0.1,
    datafolder="data",
    prefix="", cleanup::Bool=false, overwrite::Bool=false)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = DiagGraphConfig(; filling=0.8, n=sz, m=sz, seed=sd)
        config = GraphProblemConfig(; problem="IndependentSet", graph, weights=nothing, openvertices=Int[])
        maxn = load_property(foldername(datafolder, config; create=false, prefix), SizeMax()).n
        K = ceil(Int, maxn * alpha)
        prop = ConfigsMax(K; tree_storage=true, bounded=true)
        folder = foldername(datafolder, config; create=false, prefix)
        fd = joinpath(folder, "$(GraphUtilities.unique_string(prop)).dat")
        if cleanup
            if ispath(fd) 
                println("Removing MISs of size `$(maxn-K+1):$(maxn)`: $(fd)")
                rm(fd, recursive=true)
            else
                println("Did not find files for MISs of size `$(maxn-K+1):$(maxn)`: $(fd)")
            end
        else
            if !overwrite && ispath(fd) 
                println("Find existing data for MISs of size `$(maxn-K+1):$(maxn): $(fd)`, pass")
            else
                println("Computing MISs of size `$(maxn-K+1):$(maxn)`")
                load_and_compute(datafolder, config, prop; prefix, cudadevice=-1)
            end
        end
    end
end

@cast function ogp_regular(size::Int;
    sizestop::Int=size, sizestep::Int=1,
    degree=3, seed::Int=1, seedstop::Int=seed,
    alpha::Float64=0.1,
    datafolder="data",
    prefix="", cleanup::Bool=false, overwrite::Bool=false)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = RegularGraphConfig(; degree, size=sz, seed=sd)
        config = GraphProblemConfig(; problem="IndependentSet", graph, weights=nothing, openvertices=Int[])
        maxn = load_property(foldername(datafolder, config; create=false, prefix), SizeMax()).n
        K = ceil(Int, maxn * alpha)

        prop = ConfigsMax(K; tree_storage=true, bounded=true)
        folder = foldername(datafolder, config; create=false, prefix)
        fd = joinpath(folder, "$(GraphUtilities.unique_string(prop)).dat")
        if cleanup
            if ispath(fd) 
                println("Removing MISs of size `$(maxn-K+1):$(maxn)`: $(fd)")
                rm(fd, recursive=true)
            else
                println("Did not find files for MISs of size `$(maxn-K+1):$(maxn)`: $(fd)")
            end
        else
            if !overwrite && ispath(fd) 
                println("Find existing data for MISs of size `$(maxn-K+1):$(maxn): $(fd)`, pass")
            else
                println("Computing MISs of size `$(maxn-K+1):$(maxn)`")
                load_and_compute(datafolder, config, prop; prefix, cudadevice=-1)
            end
        end
    end
end

@cast function hamming(name::String, size::Int;
    sizestop::Int=size, sizestep::Int=1,
    degree=3, seed::Int=1, seedstop::Int=seed,
    datafolder="data", overwrite::Bool=false, alpha::Float64=0.1, alpha0::Float64=alpha,
    prefix="", nsample = 10000)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        if name == "regular"
            graph = RegularGraphConfig(; degree, size=sz, seed=sd)
        elseif name == "diag"
            graph = DiagGraphConfig(; n=sz, m=sz, filling=0.8, seed=sd)
        else
            error("")
        end
        config = GraphProblemConfig(; problem="IndependentSet", graph, weights=nothing, openvertices=Int[])
        folder = foldername(datafolder, config; create=false, prefix)
        maxn = load_property(folder, SizeMax()).n
        K = ceil(Int, maxn * alpha0)
        Kreal = ceil(Int, maxn * alpha)
        fd = joinpath(folder, "hamming-K$(Kreal)-n$(nsample).dat")
        if !overwrite && ispath(fd) 
            println("Hamming distance file exists for MISs of size `$(maxn-Kreal+1):$(maxn)`: $fd")
        end
        println("Hamming for MISs of size `$(maxn-Kreal+1):$(maxn)`")
        configs = load_property(folder, ConfigsMax(K; tree_storage=true, bounded=true))
        if K == 1
            tree = configs.c
        else
            tree = sum(configs.coeffs[end-Kreal+1:end])
        end
        samples = generate_samples(tree, 2*nsample);
        hd = hamming_distribution(samples[1:nsample], samples[nsample+1:2*nsample])
        writedlm(fd, hd)
    end
end

@main
