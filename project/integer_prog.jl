using JuMP
using HiGHS
using SCS
using LinearAlgebra

using Graphs
using GenericTensorNetworks
using Random
#g = smallgraph(:petersen)
g = random_diagonal_coupled_graph(10, 10, 0.8)

# MIT course: http://people.csail.mit.edu/moitra/854.html
function maxcut_ilp(g::SimpleGraph; optimizer=HiGHS.Optimizer)
    ws = ones(Int,ne(g))
    edgs = collect(edges(g))
    model = Model(optimizer)
    @variable model xs[1:nv(g)] Bin
    @variable model zs[1:ne(g)] Bin
    @constraint model [i=1:ne(g)] zs[i] <= xs[edgs[i].src] + xs[edgs[i].dst]
    @constraint model [i=1:ne(g)] zs[i] <= 2 - xs[edgs[i].src] - xs[edgs[i].dst]
    @objective model Max ws' * zs 
    optimize!(model)
    return objective_value(model), value.(xs)
end

# see also: https://jump.dev/JuMP.jl/stable/tutorials/conic/max_cut_sdp/
function maxcut_relaxed_sdp(g::SimpleGraph; optimizer=SCS.Optimizer)
    L = laplacian_matrix(g)
    model = Model(optimizer)
    # Start with X as the identity matrix to avoid numerical issues.
    @variable model X[i=1:nv(g), j=1:nv(g)] PSD start=(i==j ? 1.0 : 0.0)
    @constraint model diag(X) .== 1
    @objective model Max 0.25 * dot(L, X)
    optimize!(model)
    @assert termination_status(model) == MOI.OPTIMAL
    return objective_value(model), value.(X)
end

function goemans_williamson_postprocess(X)
    num_vertex = size(X, 1)
    # small positive number to avoid zero
    V = cholesky(X + 1e-3 * I).U
    # Generate random vector on unit sphere.
    r = rand(size(V, 1))
    r /= LinearAlgebra.norm(r)
    # Iterate over vertices, and assign each vertex to a side of cut.
    cut = ones(num_vertex)
    for i in 1:num_vertex
        if LinearAlgebra.dot(r, V[:, i]) <= 0
            cut[i] = -1
        end
    end
    return cut
end

function goemans_williamson(g::SimpleGraph)
    loss, X = maxcut_relaxed_sdp(g)
    @info "Got loss = $(loss)"
    return goemans_williamson_postprocess(X)
end

@time solve(MaxCut(g; optimizer=TreeSA(ntrials=3, βs=0.1:0.1:30, niters=10, sc_target=25)), SizeMax())
#function addvar!(model::Model, ::Type{T}, name::String; lower_bound::Union{T,Nothing}=nothing, upper_bound::Union{T,Nothing}=nothing, fixed_value::Union{T,Nothing}=nothing, start) where T
#end
#JuMP.add_variable(model, JuMP.build_variable(error, JuMP.VariableInfo(true, 0, false, NaN, false, NaN, false, NaN, false, true)), "x")
#model[:x] = var"#25###291"