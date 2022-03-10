# The data folder layout
# Graph Instance (hash)
#    info.json
#    tensornetwork.json
#    SizeMax{2}/
#    ConfigsMax{2}/
#        size_10.dat
#        size_9.dat

# kwargs ∈ [optimizer, simplifier]
function foldername(basefolder::String, config::GraphProblemConfig; create, prefix="")
    # create a parameter dict
    # use the hash of dictionary as the folder name
    name = joinpath(basefolder, prefix * unique_string(config))

    # create folder
    if create && !isdir(name)
        mkpath(name)
    end
    if create
        # create info file
        js = joinpath(name, "info.toml")
        @info "writing configuration to: $(js)"
        # dump config to toml file
        to_toml(js, config)
    end
    return name
end
        
function save_code(folder, problem::GraphProblem)
    # write tensor network contraction pattern
    filename = joinpath(folder, "tensornetwork.json")
    @info "saving contraction tree to: $(filename)"
    GraphTensorNetworks.writejson(filename, problem.code)
end

function load_code(config::GraphProblemConfig, folder)
    # write tensor network contraction pattern
    filename = joinpath(folder, "tensornetwork.json")
    @info "loading contraction tree from: $(filename)"
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
    elseif property isa SingleConfigMax{1} || property isa SingleConfigMin{1}
        c = data.c.data
        writedlm(fd, [data.n, get_s(c), c...])
    elseif property isa SingleConfigMax || property isa SingleConfigMin
        writedlm(fd, vcat([[di.n, get_s(di.c.data), di.c.data...]' for di in data.orders]...))
    elseif property isa ConfigsMax || property isa ConfigsMin
        if property isa ConfigsMax{1} || property isa ConfigsMin{1}
            sizes = [data.n]
            bls = get_n(data.c)
            configs = [data.c]
        else
            sizes = collect(data.maxorder-length(data.coeffs)+1:data.maxorder)
            bls = get_n(data.coeffs[1])
            configs = [data.coeffs...]
        end
        !isdir(fd) && mkdir(fd)
        writedlm(joinpath(fd, "sizes.dat"), sizes)
        writedlm(joinpath(fd, "bitlength.dat"), bls)
        saveconfigs(fd, sizes, configs)
    elseif property isa ConfigsAll
        !isdir(fd) && mkdir(fd)
        writedlm(joinpath(fd, "bitlength.dat"), get_n(data))
        saveconfigs(fd, ["all"], [data])
    else
        error("unknown property: `$property`.")
    end

end
get_s(::StaticElementVector{N,S,C}) where {N,S,C} = S
get_n(::ConfigEnumerator{N,S,C}) where {N,S,C} = N
get_n(::TreeConfigEnumerator{N,S,C}) where {N,S,C} = N
get_t(::ConfigsMax{K,B,T}) where {K,B,T} = T
get_t(::ConfigsMin{K,B,T}) where {K,B,T} = T
get_t(::ConfigsAll{T}) where {T} = T

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
    elseif property isa SingleConfigMax{1} || property isa SingleConfigMin{1}
        data = readdlm(fd)
        n, s = data[1], Int(data[2])
        return CountingTropical(n, ConfigSampler(StaticElementVector(2^s, Int.(data[3:end]))))
    elseif property isa SingleConfigMax || property isa SingleConfigMin
        data = readdlm(fd)
        s = Int(data[1,2])
        orders = map(1:size(data, 1)) do i
            di = data[i,:]
            n = di[1]
            CountingTropical(n, ConfigSampler(StaticElementVector(2^s, Int.(di[3:end]))))
        end
        return ExtendedTropical{size(data, 1)}(orders)
    elseif property isa ConfigsMax || property isa ConfigsMin
        sizes = vec(readdlm(joinpath(fd, "sizes.dat")))
        bitlength = Int(readdlm(joinpath(fd, "bitlength.dat"))[])
        data = loadconfigs(fd, sizes; tree_storage=get_t(property), bitlength=bitlength)
        if property isa ConfigsMax{1} || property isa ConfigsMin{1}
            return CountingTropical(T(sizes[]), data[])
        else
            return TruncatedPoly((data...,), T(sizes[end]))
        end
    elseif property isa ConfigsAll
        bitlength = Int(readdlm(joinpath(fd, "bitlength.dat"))[])
        data = loadconfigs(fd, ["all"]; tree_storage=get_t(property), bitlength=bitlength)
        return data[]
    else
        error("unknown property: `$property`.")
    end

end