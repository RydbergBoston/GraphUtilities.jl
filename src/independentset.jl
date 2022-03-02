function generate_max_configurations(graph, problem; basefolder::String, K::Int, tree_storage::Bool)
    property = ConfigsMax(K; tree_storage)
    r = solve(problem, property)[]
    # extracting data
    sizes, configs = if K == 1
        [r.n], [r.c]
    else
        collect(r.maxorder-K+1:r.maxorder), r.coeffs
    end

    # saving data
    fout = foldername(basefolder, graph, typeof(problem), typeof(property); create=true)
    saveconfigs(fout, sizes, configs)
end

function extract_samples(model; folder)
end