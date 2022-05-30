using GraphUtilities, Graphs, GenericTensorNetworks
using GraphUtilities: save_property, load_property, SmallGraphConfig
using Test

@testset "file io" begin
    # creating file
    graph = SmallGraphConfig("petersen")
    config = GraphProblemConfig(problem="IndependentSet", graph=graph)
    folder = GraphUtilities.foldername("data", config; create=true)
    @test isdir(folder)
    @test isfile(joinpath(folder, "info.toml"))
    graph = SmallGraphConfig("petersen")
    config = GraphProblemConfig(problem="IndependentSet", graph=graph)
    folder2 = GraphUtilities.foldername("data", config; create=false)
    @test folder2 == folder

    # save load problem code
    gp = problem_instance(config)
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

@testset "save property" begin
    # create a folder
    graph = SmallGraphConfig("petersen")
    config = GraphProblemConfig(; problem="IndependentSet", graph=graph)
    folder = GraphUtilities.foldername("data", config; create=true)

    # instantiate a graph problem
    gp = problem_instance(config)
    GraphUtilities.save_code(folder, gp)
    gp2 = GraphUtilities.load_code(config, folder)

    for property in [SizeMax(), SizeMin(), SizeMax(3), SizeMin(3), CountingAll(),
        CountingMax(), CountingMin(), CountingMax(3), CountingMin(3), GraphPolynomial(),
        SingleConfigMax(; bounded=false), SingleConfigMin(; bounded=false), SingleConfigMax(3; bounded=false), SingleConfigMin(3; bounded=false),
        SingleConfigMax(; bounded=true), SingleConfigMin(; bounded=true), SingleConfigMax(3; bounded=true), SingleConfigMin(3; bounded=true),
        ConfigsMax(; bounded=true, tree_storage=true), ConfigsMin(; bounded=true, tree_storage=false),
        ConfigsMax(; bounded=false, tree_storage=true), ConfigsMin(; bounded=false, tree_storage=false),
        ConfigsMax(3; bounded=true, tree_storage=true), ConfigsMin(3; bounded=true, tree_storage=false),
        ConfigsMax(3; bounded=false, tree_storage=true), ConfigsMin(3; bounded=false, tree_storage=false),
        ConfigsAll{true}(), ConfigsAll{false}()
        ]
        @show property
        res = solve(gp2, property)[]
        save_property(folder, property, res)
        @test load_property(folder, property) == res
    end
end