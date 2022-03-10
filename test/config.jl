using Test, GraphUtilities, GraphTensorNetworks
using GraphUtilities: parsegraph, parseproblem, RegularGraphConfig, to_toml, from_toml

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

