module GraphUtilities

using GraphTensorNetworks, Graphs
using JSON, DelimitedFiles
using Serialization
using Configurations, Random

export GraphProblemConfig, instantiate, foldername
export SmallGraphConfig, DiagGraphConfig, SquareGraphConfig, RegularGraphConfig
export save_property, load_property

include("config.jl")
include("fileio.jl")
include("independentset.jl")
include("maxcut.jl")

end
