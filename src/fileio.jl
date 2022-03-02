# the hash for the task, it is used to store/load the instance.
function instance_hash(edgs, ::Type{P}, ::Type{PROP}; kwargs...) where {P<:GraphProblem, PROP<:GraphTensorNetworks.AbstractProperty}
    return hash((edgs, P, PROP, kwargs))
end
function foldername(basefolder::String, g::SimpleGraph, ::Type{P}, ::Type{PROP}; create, kwargs...) where {P<:GraphProblem, PROP<:GraphTensorNetworks.AbstractProperty}
    # NOTE: for UDG, we need more info about locations.
    edgs = ([minmax(e.src, e.dst) for e in edges(g)]...,)
    name = joinpath(basefolder, string(instance_hash(edgs, P, PROP; kwargs...)))
    # create folder
    if create && !isdir(name)
        mkpath(name)
    end
    # create info file
    js = joinpath(name, "info.xml")
    if create# && !isfile(js)
        d = Dict{String,Any}("edges"=>collect(collect.(Int,edgs)), "problem"=>string(P), "property"=>string(PROP))
        for (k, v) in kwargs
            d[string(k)] = v
        end
        open(js, "w") do f
            JSON.print(f, d, 4)
        end
    end
    return name
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
