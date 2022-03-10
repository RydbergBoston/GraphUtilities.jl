# The data folder layout
# Graph Instance (hash)
#    info.json
#    tensornetwork.json
#    SizeMax{2}/
#    ConfigsMax{2}/
#        size_10.dat
#        size_9.dat

struct GraphProblemConfig{PT<:GraphProblem, WT<:Union{NoWeight, Vector}, TT<:NTuple}
    type::Type{PT}
    graph::SimpleGraph{Int}
    weights::WT
    openvertices::TT
end

function GraphProblemConfig(type::Type{<:GraphProblem}, graph::SimpleGraph; weights=NoWeight(), openvertices=())
    return GraphProblemConfig(type, graph, weights, openvertices)
end

for PT in [:IndependentSet, :MaximalIS, :DominatingSet, :MaxCut]
    # kwargs ∈ [optimizer, simplifier]
    @eval function instantiate(config::GraphProblemConfig{PT}; kwargs...) where PT<:$PT
        $PT(config.graph; weights=config.weights, openvertices=config.openvertices, kwargs...)
    end
    @eval function instantiate(config::GraphProblemConfig{PT}, code; kwargs...) where PT<:$PT
        $PT(code, config.graph, config.weights)
    end
end
for PT in [:Matching, :Coloring]
    # kwargs ∈ [optimizer, simplifier]
    @eval function instantiate(config::GraphProblemConfig{PT}; kwargs...) where PT<:$PT
        @assert config.weights isa NoWeight
        $PT(config.graph; openvertices=config.openvertices, kwargs...)
    end
    @eval function instantiate(config::GraphProblemConfig{PT}, code) where PT<:$PT
        @assert config.weights isa NoWeight
        $PT(code, config.graph)
    end
end

function foldername(basefolder::String, config::GraphProblemConfig; create, prefix="")
    # create a parameter dict
    d = dump_args(config)
    # use the hash of dictionary as the folder name
    name = joinpath(basefolder, prefix * string(hash(d)))

    # create folder
    if create && !isdir(name)
        mkpath(name)
        # create info file
        js = joinpath(name, "info.json")
        # dump to file
        open(js, "w") do f
            JSON.print(f, d, 4)
        end
    end
    return name
end
        
function dump_args(config::PT) where PT<:GraphProblemConfig
    return Dict{String,Any}(
        "type" => string(config.type),
        "graph" => dump_args(config.graph),
        "weights" => config.weights isa NoWeight ? Int[] : config.weights,
        "openvertices" => collect(config.openvertices),
    )
end
function dump_args(g::SimpleGraph)
    return Dict{String, Any}(
        "ne" => g.ne,
        "fadjlist" => g.fadjlist
    )
end

function save_code(folder, problem::GraphProblem)
    # write tensor network contraction pattern
    filename = joinpath(folder, "tensornetwork.json")
    GraphTensorNetworks.writejson(filename, problem.code)
end

function load_code(config::GraphProblemConfig, folder)
    # write tensor network contraction pattern
    filename = joinpath(folder, "tensornetwork.json")
    code = GraphTensorNetworks.readjson(filename)
    return instantiate(config, code)
end

function saveconfigs(folderout, sizes, configs::AbstractVector{<:Union{ConfigEnumerator, TreeConfigEnumerator}})
    for (s, c) in zip(sizes, configs)
        fname = joinpath(folderout, "size_$(s).dat")
        if c isa ConfigEnumerator
            save_configs(fname, c; format=:binary)
        else
            serialize(fname, c)
        end
    end
end

function loadconfigs(folderin, sizes; tree_storage::Bool, bitlength::Int)
    configs = []
    for s in sizes
        fname = joinpath(folderin, "size_$(s).dat")
        push!(configs, if tree_storage
                deserialize(fname)
            else
                load_configs(fname; format=:binary, bitlength=bitlength)
            end
        )
    end
    return configs
end

function save_property(folder::String, property::GraphTensorNetworks.AbstractProperty, data)
    fd = joinpath(folder, "$(typeof(property)).dat")
    if property isa SizeMax{1} || property isa SizeMin{1}
        writedlm(fd, data.n)
    elseif property isa SizeMax || property isa SizeMin
        writedlm(fd, getfield.(data.orders, :n))
    elseif property isa CountingAll
        writedlm(fd, data)
    elseif property isa CountingMax{1} || property isa CountingMin{1}
        writedlm(fd, [data.n, data.c]')
    elseif property isa CountingMax || property isa CountingMin
        K = length(data.coeffs)
        writedlm(fd, hcat(collect.(zip(data.maxorder-K+1:data.maxorder, data.coeffs))...)')
    elseif property isa GraphPolynomial
        writedlm(fd, data.coeffs)
    elseif property isa SingleConfigMax{1,false} || property isa SingleConfigMin{1,false}
        c = data.c.data
        writedlm(fd, [data.n, get_s(c), c...])
    elseif property isa (SingleConfigMax{K,false} where K) || property isa (SingleConfigMin{K,false} where K)
        writedlm(fd, vcat([[di.n, get_s(di.c.data), di.c.data...]' for di in data.orders]...))
    elseif property isa ConfigsMax{1,false}
        writedlm(fd, data.coeffs)
    elseif property isa ConfigsMin{1,false}
        writedlm(fd, data.coeffs)
    elseif property isa (ConfigsMax{K, false} where K)
        writedlm(fd, data.coeffs)
    elseif property isa (ConfigsMin{K, false} where K)
        writedlm(fd, data.coeffs)
    elseif property isa ConfigsAll
        writedlm(fd, data.coeffs)
    elseif property isa SingleConfigMax{1,true}
        writedlm(fd, data.coeffs)
    elseif property isa (SingleConfigMax{K,true} where K)
        @warn "bounded `SingleConfigMax` property for `K != 1` is not implemented. Switching to the unbounded version."
        writedlm(fd, data.coeffs)
    elseif property isa SingleConfigMin{1,true}
        writedlm(fd, data.coeffs)
    elseif property isa (SingleConfigMin{K,true} where K)
        @warn "bounded `SingleConfigMin` property for `K != 1` is not implemented. Switching to the unbounded version."
        writedlm(fd, data.coeffs)
    elseif property isa ConfigsMax{1,true}
        writedlm(fd, data.coeffs)
    elseif property isa ConfigsMin{1,true}
        writedlm(fd, data.coeffs)
    elseif property isa (ConfigsMax{K,true} where K)
        writedlm(fd, data.coeffs)
    elseif property isa (ConfigsMin{K,true} where K)
        writedlm(fd, data.coeffs)
    else
        error("unknown property: `$property`.")
    end

end
get_s(::StaticElementVector{N,S,C}) where {N,S,C} = S

function load_property(folder::String, property::GraphTensorNetworks.AbstractProperty; T=Float64)
    fd = joinpath(folder, "$(typeof(property)).dat")
    if property isa SizeMax{1} || property isa SizeMin{1}
        return Tropical(readdlm(fd, T)[])
    elseif property isa SizeMax || property isa SizeMin
        orders = readdlm(fd, T)
        return ExtendedTropical{length(orders)}(Tropical.(vec(orders)))
    elseif property isa CountingAll
        return readdlm(fd, T)[]
    elseif property isa CountingMax{1} || property isa CountingMin{1}
        n, c = vec(readdlm(fd, T))
        return CountingTropical(n, c)
    elseif property isa CountingMax || property isa CountingMin
        data = readdlm(fd)
        return TruncatedPoly((data[:,2]...,), data[end,1])
    elseif property isa GraphPolynomial
        return Polynomial(vec(readdlm(fd)))
    elseif property isa SingleConfigMax{1,false} || property isa SingleConfigMin{1,false}
        data = readdlm(fd)
        n, s = data[1], Int(data[2])
        return CountingTropical(n, ConfigSampler(StaticElementVector(2^s, Int.(data[3:end]))))
    elseif property isa (SingleConfigMax{K,false} where K) || property isa (SingleConfigMin{K,false} where K)
        data = readdlm(fd)
        s = Int(data[1,2])
        orders = map(1:size(data, 1)) do i
            di = data[i,:]
            n = di[1]
            CountingTropical(n, ConfigSampler(StaticElementVector(2^s, Int.(di[3:end]))))
        end
        return ExtendedTropical{size(data, 1)}(orders)
    elseif property isa ConfigsMax{1,false}
        readdlm(fd, data.coeffs)
    elseif property isa ConfigsMin{1,false}
        readdlm(fd, data.coeffs)
    elseif property isa (ConfigsMax{K, false} where K)
        readdlm(fd, data.coeffs)
    elseif property isa (ConfigsMin{K, false} where K)
        readdlm(fd, data.coeffs)
    elseif property isa ConfigsAll
        readdlm(fd, data.coeffs)
    elseif property isa SingleConfigMax{1,true}
        readdlm(fd, data.coeffs)
    elseif property isa (SingleConfigMax{K,true} where K)
        @warn "bounded `SingleConfigMax` property for `K != 1` is not implemented. Switching to the unbounded version."
        readdlm(fd, data.coeffs)
    elseif property isa SingleConfigMin{1,true}
        readdlm(fd, data.coeffs)
    elseif property isa (SingleConfigMin{K,true} where K)
        @warn "bounded `SingleConfigMin` property for `K != 1` is not implemented. Switching to the unbounded version."
        readdlm(fd, data.coeffs)
    elseif property isa ConfigsMax{1,true}
        readdlm(fd, data.coeffs)
    elseif property isa ConfigsMin{1,true}
        readdlm(fd, data.coeffs)
    elseif property isa (ConfigsMax{K,true} where K)
        readdlm(fd, data.coeffs)
    elseif property isa (ConfigsMin{K,true} where K)
        readdlm(fd, data.coeffs)
    else
        error("unknown property: `$property`.")
    end

end