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
    GenericTensorNetworks.writejson(filename, problem.code)
end

function load_code(config::GraphProblemConfig, folder)
    # write tensor network contraction pattern
    filename = joinpath(folder, "tensornetwork.json")
    @info "loading contraction tree from: $(filename)"
    code = GenericTensorNetworks.readjson(filename)
    return problem_instance(config, code)
end

function saveconfigs(folderout, sizes, configs::AbstractVector{<:Union{ConfigEnumerator, SumProductTree}})
    for (s, c) in zip(sizes, configs)
        fname = joinpath(folderout, "size_$(s).dat")
        if c isa ConfigEnumerator
            save_configs(fname, c; format=:binary)
        else
            save_sumproduct(fname, c)
        end
    end
end

function loadconfigs(folderin, sizes; tree_storage::Bool, bitlength::Int)
    configs = []
    for s in sizes
        fname = joinpath(folderin, "size_$(s).dat")
        push!(configs, if tree_storage
                load_sumproduct(fname)
            else
                load_configs(fname; format=:binary, bitlength=bitlength)
            end
        )
    end
    return configs
end

function save_property(folder::String, property::GenericTensorNetworks.AbstractProperty, data)
    fd = joinpath(folder, "$(unique_string(property)).dat")
    @info "saving result to file/folder: $(fd)"
    if property isa SizeMax{Single} || property isa SizeMin{Single}
        writedlm(fd, data.n)
    elseif property isa SizeMax || property isa SizeMin
        writedlm(fd, getfield.(data.orders, :n))
    elseif property isa CountingAll
        writedlm(fd, data)
    elseif property isa CountingMax{Single} || property isa CountingMin{Single}
        writedlm(fd, [data.n, data.c]')
    elseif property isa CountingMax || property isa CountingMin
        K = length(data.coeffs)
        writedlm(fd, hcat(collect.(zip(data.maxorder-K+1:data.maxorder, data.coeffs))...)')
    elseif property isa GraphPolynomial
        writedlm(fd, data.coeffs)
    elseif property isa SingleConfigMax{Single} || property isa SingleConfigMin{Single}
        c = data.c.data
        writedlm(fd, [data.n, get_s(c), c...])
    elseif property isa SingleConfigMax || property isa SingleConfigMin
        writedlm(fd, vcat([[di.n, get_s(di.c.data), di.c.data...]' for di in data.orders]...))
    elseif property isa ConfigsMax || property isa ConfigsMin
        if property isa ConfigsMax{Single} || property isa ConfigsMin{Single}
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
get_n(::SumProductTree{OnehotVec{N,F}}) where {N,F} = N
get_t(::ConfigsMax{K,B,T}) where {K,B,T} = T
get_t(::ConfigsMin{K,B,T}) where {K,B,T} = T
get_k(::ConfigsMax{K,B,T}) where {K,B,T} = K
get_k(::ConfigsMin{K,B,T}) where {K,B,T} = K
get_t(::ConfigsAll{T}) where {T} = T

function load_property(folder::String, property::GenericTensorNetworks.AbstractProperty; T=Float64)
    fd = joinpath(folder, "$(unique_string(property)).dat")
    if property isa SizeMax{Single} || property isa SizeMin{Single}
        return Tropical(readdlm(fd, T)[])
    elseif property isa SizeMax || property isa SizeMin
        orders = readdlm(fd, T)
        return ExtendedTropical{length(orders)}(Tropical.(vec(orders)))
    elseif property isa CountingAll
        return readdlm(fd, T)[]
    elseif property isa CountingMax{Single} || property isa CountingMin{Single}
        n, c = vec(readdlm(fd, T))
        return CountingTropical(n, c)
    elseif property isa CountingMax || property isa CountingMin
        data = readdlm(fd)
        return TruncatedPoly((data[:,2]...,), data[end,1])
    elseif property isa GraphPolynomial
        return Polynomial(vec(readdlm(fd)))
    elseif property isa SingleConfigMax{Single} || property isa SingleConfigMin{Single}
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
        K = get_k(property)
        sizes = vec(readdlm(joinpath(fd, "sizes.dat")))[end-K+1:end]
        bitlength = Int(readdlm(joinpath(fd, "bitlength.dat"))[])
        data = loadconfigs(fd, sizes; tree_storage=get_t(property), bitlength=bitlength)
        if property isa ConfigsMax{Single} || property isa ConfigsMin{Single}
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
