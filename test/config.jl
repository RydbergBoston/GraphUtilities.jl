using Test, GraphUtilities, GenericTensorNetworks
using GraphUtilities: parsegraph, parseproblem, RegularGraphConfig, to_toml, from_toml, parseproperty

@testset "parse config" begin
    gc = RegularGraphConfig(; size=10, degree=3)
    gp = GraphProblemConfig(; problem="IndependentSet", graph=gc)
    to_toml("_test.toml", gp)
    @test gp isa GraphProblemConfig
    @test parsegraph(gp.graph).ne == 15
    @test parseproblem(gp.problem) === IndependentSet
    gp2 = from_toml(GraphProblemConfig, "_test.toml")
    @test gp == gp2
    @test hash(gp) == hash(gp2)
end

@testset "parse property" begin
    @test parseproperty("SizeMax2") == SizeMax(2)
    @test parseproperty("SizeMax") == SizeMax()
    @test parseproperty("ConfigsMax2") == ConfigsMax(2)
    @test parseproperty("ConfigsMin2") == ConfigsMin(2)
    @test parseproperty("SingleConfigMax3") == SingleConfigMax(3)
    @test parseproperty("SingleConfigMin3") == SingleConfigMin(3)
    @test parseproperty("ConfigsAll") == ConfigsAll()
    @test parseproperty("GraphPolynomial") == GraphPolynomial()
    @test parseproperty("CountingMax") == CountingMax()
    @test parseproperty("CountingMin4") == CountingMin(4)
    @test parseproperty("CountingAll") == CountingAll()
    @test parseproperty("ConfigsMaxTree3") == ConfigsMax(3; tree_storage=true)
    @test parseproperty("ConfigsMinTree3") == ConfigsMin(3; tree_storage=true)
    @test parseproperty("ConfigsAllTree") == ConfigsAll(; tree_storage=true)
end