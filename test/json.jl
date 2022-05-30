using GraphUtilities, GenericTensorNetworks, Graphs
using Test

@testset "json solve" begin
    for property in ["SizeMax", "SizeMin",
            "SizeMax3", "SizeMin3", "CountingAll",
            "CountingMax", "CountingMin", "CountingMax3", "CountingMin3", "GraphPolynomial",
            "SingleConfigMax", "SingleConfigMin", "SingleConfigMax3", "SingleConfigMin3",
            "ConfigsMaxTree", "ConfigsMin",
            "ConfigsMaxTree3", "ConfigsMin3",
            "ConfigsAll", "ConfigsAllTree"
        ]
        res = GraphUtilities.json_solve(Dict(
            "graph"=>Dict("nv"=>10, "edges"=>[[e.src, e.dst] for e in edges(smallgraph(:petersen))]),
            "problem"=>"MaximalIS", 
            "property"=>property,
            "openvertices"=>[],
            "fixedvertices"=>Dict(),
            "optimizer"=>Dict(
                "method"=>"TreeSA",
                "sc_target"=>20,
                "sc_weight"=>1.0,
                "ntrials"=>1,
                "niters"=>5,
                "openvertices"=>[],
                "fixedvertices"=>Dict(),
                "nslices"=>0,
                "rw_weight"=>1.0,
                "betas"=>collect(0.01:0.1:30),
            ),
            "cudadevice"=>-1
        ))
        #@test res == Tropical(3.0)
        @test GraphUtilities.tojson(res) isa Dict#Dict("size"=>3.0)
    end
end