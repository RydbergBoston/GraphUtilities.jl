using Comonicon, PyPlot
using DelimitedFiles

@cast function hamming(which::String, n::Int, alpha::Float64;
            degree::Int=3)
    for seed=1:100
        @show n, seed
        if which == "regular"
            folder = joinpath("data", "IndependentSet_Regular$(n)d$(degree)seed$(seed)")
        elseif which == "diag"
            folder = joinpath("data", "IndependentSet_Diag$(n)x$(n)f0.8seed$(seed)")
        else
            error("")
        end
        maxn = readdlm(joinpath(folder, "SizeMax1.dat"))[]
        K = ceil(Int, maxn * alpha)

        hamming = readdlm(joinpath(folder, "hamming-K$(K)-n10000.dat"))
        f = plot(collect(0:length(hamming)-1), hamming)

        #ylabel("hamming distance")
        PyPlot.axis("off")
        savefig(joinpath(folder, "hamming-K$(K)-n10000.png"))
        clf()
    end
    #ylabel("hamming distance")
    #savefig(joinpath("hamming-$(which)-size$(n)-n10000.png"))
    #clf()
end

@cast function grid(which::String, n::Int, alpha::Float64;
            degree::Int=3, graphsize::Int=3)
    f, axs = subplots(graphsize, graphsize)
    for seed=1:graphsize^2
        @show n, seed
        if which == "regular"
            folder = joinpath("data", "IndependentSet_Regular$(n)d$(degree)seed$(seed)")
        elseif which == "diag"
            folder = joinpath("data", "IndependentSet_Diag$(n)x$(n)f0.8seed$(seed)")
        else
            error("")
        end
        maxn = readdlm(joinpath(folder, "SizeMax1.dat"))[]
        K = ceil(Int, maxn * alpha)

        hamming = readdlm(joinpath(folder, "hamming-K$(K)-n10000.dat")) |> vec
        axs[seed].bar(collect(0:length(hamming)-1), hamming)
        axs[seed].axis("off")
    end
    fname = "grid-$(which)-size$(n)d$(degree)-k$(graphsize)-alpha$(alpha)-n10000.pdf"
    println("saving to: $fname")
    PyPlot.suptitle("\${\\rm ratio}=$(alpha)\$", fontsize=28, y=0.07)
    savefig(fname)
end

@cast function griddata(which::String, n::Int, alpha::Float64;
            degree::Int=3, graphsize::Int=3)
    hammings = zeros(Int, 1+(which == "regular" ? n : round(Int, n^2 * 0.8)), graphsize^2)
    for seed=1:graphsize^2
        @show n, seed
        if which == "regular"
            folder = joinpath("data", "IndependentSet_Regular$(n)d$(degree)seed$(seed)")
        elseif which == "diag"
            folder = joinpath("data", "IndependentSet_Diag$(n)x$(n)f0.8seed$(seed)")
        else
            error("")
        end
        maxn = readdlm(joinpath(folder, "SizeMax1.dat"))[]
        K = ceil(Int, maxn * alpha)
        @show K

        hamming = readdlm(joinpath(folder, "hamming-K$(K)-n10000.dat")) |> vec
        hammings[:,seed] .= hamming
    end
    fname = "grid-$(which)-size$(n)d$(degree)-k$(graphsize)-alpha$(alpha)-n10000.dat"
    println("saving to: $fname")
    writedlm(fname, hammings)
end

@main
