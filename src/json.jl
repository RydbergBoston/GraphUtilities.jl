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
    method = dict["method"]
    if method == "TreeSA"
        return TreeSA(;
            sc_target=dict["sc_target"],
            sc_weight=dict["sc_weight"],
            rw_weight=dict["rw_weight"],
            ntrials=dict["ntrials"],
            niters=dict["niters"],
            nslices=dict["nslices"],
            βs=dict["betas"]
        )
    elseif method == "GreedyMethod"
        return GreedyMethod(;
            nrepeat=dict["nrepeat"]
        )
    else
        error("")
    end
end

function json_solve(dict)
    graph = loadjson_graph(dict["graph"])
    optimizer = loadjson_optimizer(dict["optimizer"])
    PROB = parseproblem(dict["problem"])
    property = parseproperty(dict["property"])

    instance = PROB(graph;
            weights=get(dict, "weights", NoWeight()),  # weights is optional
            openvertices=dict["openvertices"],
            fixedvertices=dict["fixedvertices"],
            optimizer,
            simplifier=MergeGreedy()
        )
    println("time, space, RW complexitys are $(timespacereadwrite_complexity(instance))")

    cudadevice = dict["cudadevice"]
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

function application(dict)
    dict = verify(problem_verifier(), dict)
    return tojson(json_solve(dict))
end