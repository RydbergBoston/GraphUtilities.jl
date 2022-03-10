using GraphUtilities, Graphs, GraphTensorNetworks
using Test

@testset "file io" begin
    # creating file
    graph = smallgraph(:petersen)
    config = GraphProblemConfig(IndependentSet, graph)
    folder = GraphUtilities.foldername("data", config; create=true)
    @test isdir(folder)
    @test isfile(joinpath(folder, "info.json"))
    graph = smallgraph(:petersen)
    config = GraphProblemConfig(IndependentSet, graph)
    folder2 = GraphUtilities.foldername("data", config; create=false)
    @test folder2 == folder

    # save load problem code
    gp = instantiate(config)
    GraphUtilities.save_code(folder, gp)
    gp2 = GraphUtilities.load_code(config, folder)
    for field in fieldnames(typeof(gp))
        @test getfield(gp, field) == getfield(gp2, field)
    end

    # save load configs (table)
    prop = ConfigsMax(; tree_storage=false)
    res = solve(gp, prop)[]
    fc = joinpath(folder, "table")
    !isdir(fc) && mkdir(fc)
    @show fc
    GraphUtilities.saveconfigs(fc, [res.n], [res.c])
    fname = joinpath(fc, "size_4.0.dat")
    @test isfile(fname)
    configs = GraphUtilities.loadconfigs(fc, [res.n]; tree_storage=false, bitlength=10)
    @test configs == [res.c]

    # TREE STORAGE
    # creating file
    graph = smallgraph(:petersen)
    gp = IndependentSet(graph)
    prop = ConfigsMax(; tree_storage=true)

    # save load configs (tree)
    res = solve(gp, prop)[]
    fc = joinpath(folder, "tree")
    !isdir(fc) && mkdir(fc)
    GraphUtilities.saveconfigs(fc, [res.n], [res.c])
    fname = joinpath(fc, "size_4.0.dat")
    @test isfile(fname)
    configs = GraphUtilities.loadconfigs(fc, [res.n]; tree_storage=true, bitlength=10)
    @test configs == [res.c]
end