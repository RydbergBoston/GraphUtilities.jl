using Comonicon, PyPlot
using DelimitedFiles

@cast function hamming(which::String, n::Int)
    for seed=1:100
        @show n, seed
        if which == "regular"
            folder = "IndependentSet_Regular$(n)d3seed$(seed)"
        elseif which == "diag"
            folder = "IndependentSet_Diag$(n)x$(n)f0.8seed$(seed)"
        else
            error("")
        end
        alpha = readdlm(joinpath(folder, "SizeMax1.dat"))[]
        K = ceil(Int, alpha/10)

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