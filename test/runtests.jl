using GraphUtilities, Graphs, GraphTensorNetworks
using Test

@testset "file io" begin
    # creating file
    graph = smallgraph(:petersen)
    gp = IndependentSet(graph)
    prop = ConfigsMax()
    folder = GraphUtilities.foldername("data", graph, typeof(gp), typeof(prop); tree_storage=false, create=true)
    @test isdir(folder)
    @test isfile(joinpath(folder, "info.xml"))

    # save load configs (table)
    res = solve(gp, prop)[]
    GraphUtilities.saveconfigs(folder, [res.n], [res.c])
    fname = joinpath(folder, "size_4.0.dat")
    @test isfile(fname)
    configs = GraphUtilities.loadconfigs(folder, [res.n]; tree_storage=false, bitlength=10)
    @test configs == [res.c]

    # TREE STORAGE
    # creating file
    graph = smallgraph(:petersen)
    gp = IndependentSet(graph)
    prop = ConfigsMax(; tree_storage=true)
    folder = GraphUtilities.foldername("data", graph, typeof(gp), typeof(prop); tree_storage=false, create=true)

    # save load configs (table)
    res = solve(gp, prop)[]
    GraphUtilities.saveconfigs(folder, [res.n], [res.c])
    fname = joinpath(folder, "size_4.0.dat")
    @test isfile(fname)
    configs = GraphUtilities.loadconfigs(folder, [res.n]; tree_storage=true, bitlength=10)
    @test configs == [res.c]
end