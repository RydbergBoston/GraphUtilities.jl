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
        
function load_problem(foldername::String, config::GraphProblemConfig)
    instantiate(config, load_code(config, foldername))
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
