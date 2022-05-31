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
        res = GraphUtilities.application(Dict(
            "api"=>"solve",
            "api.solve"=>Dict(
                "graph"=>Dict("nv"=>10, "edges"=>[[e.src, e.dst] for e in edges(smallgraph(:petersen))]),
                "problem"=>"MaximalIS", 
                "property"=>property,
                "openvertices"=>[],
                "fixedvertices"=>Dict(),
                "optimizer"=>Dict(
                    "method"=>"TreeSA",
                    "TreeSA"=>Dict(
                        "sc_target"=>20,
                        "sc_weight"=>1.0,
                        "ntrials"=>1,
                        "niters"=>5,
                        "openvertices"=>[],
                        "fixedvertices"=>Dict(),
                        "nslices"=>0,
                        "rw_weight"=>1.0,
                        "betas"=>collect(0.01:0.1:30)
                        )
                    ),
                "cudadevice"=>-1
            )
        ))
        @test res isa Union{Dict, Vector}
    end
    res = GraphUtilities.application(Dict(
        "api"=>"solve",
        "api.solve"=>Dict(
            "graph"=>Dict("nv"=>10, "edges"=>[[e.src, e.dst] for e in edges(smallgraph(:petersen))]),
            "problem"=>"MaximalIS", 
            "property"=>"SizeMin",
        )
    ))
    @test res == Dict("size"=>3.0)
    @test_throws GraphUtilities.VerificationError GraphUtilities.application(Dict(
        "api"=>"solve",
        "api.solve"=>Dict(
        "graph"=>Dict("nv"=>10, "edges"=>[[e.src, e.dst] for e in edges(smallgraph(:petersen))]),
        "problem"=>"MaximalIS", 
        "property"=>"SizeMi",)
    ))
end

@testset "json graph" begin
    d_graph = Dict(
        "api"=>"graph",
        "api.graph" => Dict(
            "type"=>"kings",
            "type.kings"=> Dict(
                "m"=>8, 
                "n"=>8, 
                "filling"=>0.8,
                "seed"=>2
            )
        )
    )
    res = GraphUtilities.application(d_graph)
    @test res isa Dict
end

@testset "json opteinsum" begin
    d_opteinsum = Dict("api"=>"opteinsum",
        "api.opteinsum" => Dict(
            "inputs"=>[[1,2], [2,3], [3,4], [5,4]],
            "output"=>[1,6],
            "method"=>"TreeSA",
            "sizes"=>[1=>2, 2=>2, 3=>2,
                4=>2, 5=>2]
        )
    )
    res = GraphUtilities.application(d_opteinsum)
    @test res isa Dict
    @test GraphUtilities.application(Dict("api"=>"help")) isa Dict
end