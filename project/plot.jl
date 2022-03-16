using Comonicon, PyPlot
using DelimitedFiles

@cast function hamming(which::String, n::Int, alpha::Float64)
    for seed=1:100
        @show n, seed
        if which == "regular"
            folder = joinpath("data", "IndependentSet_Regular$(n)d3seed$(seed)")
        elseif which == "diag"
            folder = joinpath("data", "IndependentSet_Diag$(n)x$(n)f0.8seed$(seed)")
        else
            error("")
        end
        maxn = readdlm(joinpath(folder, "SizeMax1.dat"))[]
        K = ceil(Int, maxn * alpha)

        hamming = readdlm(joinpath(folder, "hamming-K$(K)-n10000.dat"))
        f = plot(collect(0:length(hamming)-1), hamming)

        ylabel("hamming distance")
        savefig(joinpath(folder, "hamming-K$(K)-n10000.png"))
        clf()
    end
    #ylabel("hamming distance")
    #savefig(joinpath("hamming-$(which)-size$(n)-n10000.png"))
    #clf()
end

@main
