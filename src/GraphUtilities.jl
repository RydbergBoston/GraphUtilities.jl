module GraphUtilities

using GraphTensorNetworks, Graphs
using JSON
using Serialization

export GraphProblemConfig, instantiate

include("fileio.jl")
include("independentset.jl")
include("maxcut.jl")

end
