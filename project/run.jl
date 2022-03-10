using GraphUtilities, GraphTensorNetworks
using Comonicon

@cast function generate(problem::String, graphname::Symbol, size, seed=1, weights=NoWeight(), datafolder="data", prefix="$(graphname)_n$(n)_seed$(seed)_")
    g = generate_graph(graphname, size, seed)
    config = GraphProblemConfig(eval(Meta.parse(problem)), g; weights, openvertices=())
    foldername(datafolder, config; create=true, prefix)
end

@case function compute(problem, graphname, size, seed=1, )