module GraphUtilities

using GenericTensorNetworks, Graphs
using JSON, DelimitedFiles
using Configurations, Random

using Requires
function __init__()
    @require UnitDiskMapping="1b61a8d9-79ed-4491-8266-ef37f39e1727" using UnitDiskMapping
end

export GraphProblemConfig, problem_instance, foldername
export SmallGraphConfig, DiagGraphConfig, SquareGraphConfig, RegularGraphConfig, MISProjectGraphConfig, MappedRegularGraphConfig
export save_property, load_property

include("config.jl")
include("fileio.jl")

end
