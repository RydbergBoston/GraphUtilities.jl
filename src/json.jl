function mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_weight, rw_weight, sc_target, prefix)
    folder = foldername(datafolder, config; create=true, prefix)
    instance = problem_instance(config;
        optimizer=TreeSA(; sc_target, sc_weight, ntrials, niters, rw_weight, nslices, βs=0.01:0.05:30),
        simplifier=MergeGreedy()
        )
    println("graph size = $(nv(instance.graph))")
    println("time, space, RW complexitys are $(timespacereadwrite_complexity(instance))")
    GraphUtilities.save_code(folder, instance)
end

function get_graph(graphname, size; degree, filling, seed)
    if graphname=="diag"
        return DiagGraphConfig(; filling, n=size, m=size, seed=seed)
    elseif graphname == "regular"
        return RegularGraphConfig(; degree, size=size, seed=seed)
    elseif graphname == "square"
        return SquareGraphConfig(; filling, m=size, n=size, seed=seed)
    elseif graphname == "misproject"
        return MISProjectGraphConfig(; n=size, index=seed)
    elseif graphname == "mapped-regular"
        return MappedRegularGraphConfig(; degree, size, seed)
    else
        return SmallGraphConfig(graphname)
    end
end

function unified_solve(nv::Int, edges::Vector{Vector{Int}}, problem::String, property::String;
            weights, openvertices, fixedvertices, 
            # contraction order optimizer
            sc_target, sc_weight, ntrials, niters, rw_weight, nslices, βs=0.01:0.05:30,
            cudadevice::Int,
        )
    graph = SimpleGraph(nv)
    for (i, j) in edges
        add_edge!(graph, i, j)
    end
    PT = parseproblem(problem)
    weights = weights === nothing ? NoWeight() : weights
    instance = PT(graph; weights, openvertices=openvertices, fixedvertices=fixedvertices,
        optimizer=TreeSA(; sc_target, sc_weight, ntrials, niters, rw_weight, nslices, βs),
        simplifier=MergeGreedy()
    )

    property = GraphUtilities.parseproperty(property)

    println("time, space, RW complexitys are $(timespacereadwrite_complexity(instance))")
    if cudadevice >=0
        CUDA.device!(cudadevice)
    end
    return solve(instance, property; usecuda=cudadevice>=0)[]
end

function loadjson_graph(dict)
    nv = dict["nv"]
    edges = dict["edges"]
    graph = SimpleGraph(nv)
    for (i, j) in edges
        add_edge!(graph, i, j)
    end
    return graph
end

function loadjson_optimizer(dict)
    method = get(dict, "method", "GreedyMethod")
    if method == "TreeSA"
        return TreeSA(;
            sc_target=get(dict, "sc_target", 20),
            sc_weight=get(dict, "sc_weight", 1.0),
            rw_weight=get(dict, "rw_weight", 1.0),
            ntrials=get(dict, "ntrials", 3),
            niters=get(dict, "niters", 10),
            nslices=get(dict, "nslices", 0),
            βs=get(dict, "betas", 0.01:0.05:30)
        )
    elseif method == "GreedyMethod"
        return GreedyMethod(;
            nrepeat=get(dict, "nrepeat", 10)
        )
    else
        error("")
    end
end

function json_solve(dict)
    graph = loadjson_graph(dict["graph"])
    optimizer = loadjson_optimizer(get(dict, "optimizer", Dict()))
    PROB = parseproblem(dict["problem"])
    property = parseproperty(dict["property"])

    instance = PROB(graph;
            weights=get(dict,"weights", NoWeight()),
            openvertices=get(dict, "openvertices", Int[]),
            fixedvertices=get(dict, "fixedvertices", Dict()),
            optimizer,
            simplifier=MergeGreedy()
        )
    println("time, space, RW complexitys are $(timespacereadwrite_complexity(instance))")

    cudadevice = get(dict,"cudadevice",-1)
    cudadevice >= 0 && CUDA.device!(cudadevice)
    return solve(instance, property; usecuda=cudadevice>=0)[]
end

function tojson(data)
    if data isa Tropical
        return Dict("size"=>data.n)
    elseif data isa ExtendedTropical{K,<:Tropical} where K
        return [Dict("size"=>x.n) for x in data.orders]
    elseif data isa Real
        return Dict("count"=>data)
    elseif data isa CountingTropical{T, <:Real} where T
        return Dict("size"=>data.n, "count"=>data.c)
    elseif data isa TruncatedPoly{K, <:Real} where {K}
        K = length(data.coeffs)
        return [Dict("size"=>size, "count"=>count) for (size, count) in zip(data.maxorder-K+1:data.maxorder, data.coeffs)]
    elseif data isa Polynomial
        return [Dict("size"=>i-1, "count"=>c) for (i, c) in enumerate(data.coeffs)]
    elseif data isa CountingTropical{T, <:ConfigSampler} where T
        return Dict("size"=>data.n, "config"=>[data.c.data...])
    elseif data isa ExtendedTropical{K, <:CountingTropical{T, <:ConfigSampler}} where {K,T}
        return [Dict(
                    "size"=>di.n,
                    "config"=>[di.c.data...]
                    ) for di in data.orders
                ]
    elseif data isa CountingTropical{T, <:ConfigEnumerator} where T
        return Dict("size"=>data.n, "configs"=>[[x...] for x in data.c])
    elseif data isa TruncatedPoly{K, <:ConfigEnumerator} where K
        sizes = collect(data.maxorder-length(data.coeffs)+1:data.maxorder)
        configs = [data.coeffs...]
        return [Dict("size"=>size, "configs"=>[[x...] for x in config]) for (size, config) in zip(sizes, configs)]
    elseif data isa ConfigEnumerator
        return Dict("configs"=>[[x...] for x in data])
    elseif data isa CountingTropical{T, <:SumProductTree} where T
        return Dict("size"=>data.n, "configs"=>[[x...] for x in collect(data.c)])
    elseif data isa TruncatedPoly{K, <:SumProductTree} where K
        sizes = collect(data.maxorder-length(data.coeffs)+1:data.maxorder)
        configs = collect.([data.coeffs...])
        return [Dict("size"=>size, "configs"=>[[x...] for x in config]) for (size, config) in zip(sizes, configs)]
    elseif data isa SumProductTree
        return Dict("configs"=>[[x...] for x in collect(data)])
    else
        error("unknown data type: `$(typeof(data))`.")
    end
end

function generate(graphname::String, problem::String, size::Int;
    sizestop::Int=size, sizestep::Int=1,
    degree::Int=3, seed::Int=1, seedstop::Int=seed,
    filling::Float64=0.8,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    ntrials::Int=1, niters::Int=10, nslices::Int=0, sc_target::Int=25,
    sc_weight::Float64=1.0, rw_weight::Float64=1.0,  # config TreeSA
    )
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = get_graph(graphname, sz; degree, filling, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        mkdir_and_dumpcode(datafolder, config; ntrials, niters, nslices, sc_target, sc_weight, rw_weight, prefix)
    end
end

########################### COMPUTE ###################################
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

function compute(graphname::String, problem::String, size::Int, property::String;
    sizestop::Int=size, sizestep::Int=1,
    degree::Int=3, seed::Int=1, seedstop::Int=seed,
    filling::Float64=0.8,
    weights::Union{Nothing,Vector{Float64}}=nothing,
    datafolder::String="data", prefix::String="",
    cudadevice::Int=-1)
    for sz in size:sizestep:sizestop, sd in seed:seedstop
        println("seed = $sd, size = $(sz)")
        graph = get_graph(graphname, sz; degree, filling, seed=sd)
        config = GraphProblemConfig(; problem, graph, weights, openvertices=Int[])
        load_and_compute(datafolder, config, GraphUtilities.parseproperty(property); prefix, cudadevice)
    end
end