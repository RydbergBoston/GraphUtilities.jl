using Test

@testset "config" begin
    include("config.jl")
end

@testset "fileio" begin
    include("fileio.jl")
end

@testset "json" begin
    include("json.jl")
end