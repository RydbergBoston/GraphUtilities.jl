struct NoDefault end

struct Verifier
    type
    f
    default
    optional::Bool
    forfield::String
end
struct VerifierTree
    dict::Dict
    optional::Bool
    forfield::String
end
VerifierTree(dict::Dict; optional=false, forfield="") = VerifierTree(dict, optional, forfield)

struct VerificationError <: Exception
    msg::String
end
function Verifier(::Type{T}, f=@λ x->true; default=NoDefault(), optional=false, forfield="") where T
    if default !== NoDefault()
        if !(default isa T)
            error("The type of default value `$default` does not match the required type `$T`!")
        elseif !f(default)
            error("The default value does not pass the checker!")
        end
    end
    Verifier(T, f, default, optional, forfield)
end

function verify(tree::VerifierTree, dict)
    updated = Dict()
    # sort the fields for that the dependent fields are updated the last
    kvpairs = [(k,v) for (k, v) in tree.dict]
    sort!(kvpairs, by=x->!isempty(x[2].forfield))
    for (k, v) in kvpairs
        if !isempty(v.forfield)  # check target field
            method = updated[v.forfield]
            if method != k   # we do not need to extract this conditional field!
                continue
            end
        end
        if v isa VerifierTree
            # recurse
            if !haskey(dict, k)
                if !v.optional
                    throw(VerificationError("Required argument absent: $k"))
                else
                    updated[k] = verify(v, Dict())
                end
            else
                updated[k] = verify(v, dict[k])
            end
        else
            # verify
            if !haskey(dict, k)
                if v.default === NoDefault()
                    if !v.optional
                        throw(VerificationError("Required argument absent: $k"))
                    else
                        # leave it empty
                    end
                else
                    updated[k] = v.default
                end
            else
                val = dict[k]
                # type check
                if !(val isa v.type)
                    try
                        val = v.type(val)   # type cast
                    catch
                        throw(VerificationError("Input argument type should be $(v.type), got: $(typeof(val))"))
                    end
                end
                # f check
                if !v.f(val)
                    throw(VerificationError("Input argument does not pass verifier $(v.f), got: $val"))
                end
                updated[k] = val
            end
        end
    end
    return updated
end

function graph_verifier()
    Dict("nv"=>Verifier(Int, @λ x->1<=x),
        "edges"=>Verifier(Vector{Vector{Int}}, @λ x->all(e->length(e)==2, x)))
end

function optimizer_verifier()
    Dict("method"=>Verifier(String, @λ x->x ∈ ["TreeSA", "GreedyMethod"]; default="GreedyMethod"),
        "TreeSA"=>VerifierTree(Dict(
            "sc_target"=> Verifier(Float64; default=20.0),
            "sc_weight" => Verifier(Float64; default=1.0),
            "rw_weight" => Verifier(Float64; default=1.0),
            "ntrials" => Verifier(Int, @λ x -> x > 0; default=3),
            "niters" => Verifier(Int, @λ x -> x > 0; default=10),
            "nslices" => Verifier(Int, @λ x-> x>= 0; default=0),
            "betas" => Verifier(Vector{Float64}, @λ x->length(x)>0; default=collect(0.01:0.05:30.0)),
        ); forfield="method", optional=true),
        "GreedyMethod"=>VerifierTree(Dict(
            "nrepeat" => Verifier(Int, @λ x->length(x)>0; default=10)
        ); forfield="method", optional=true)
    )
end

function problem_verifier()
    VerifierTree(Dict("property"=>Verifier(String, @λ x -> x ∈ ["SizeMax", "SizeMin",
                "SizeMax3", "SizeMin3", "CountingAll",
                "CountingMax", "CountingMin", "CountingMax3", "CountingMin3", "GraphPolynomial",
                "SingleConfigMax", "SingleConfigMin", "SingleConfigMax3", "SingleConfigMin3",
                "ConfigsMaxTree", "ConfigsMin",
                "ConfigsMaxTree3", "ConfigsMin3",
                "ConfigsAll", "ConfigsAllTree"
                ]),
            "problem"=>Verifier(String, @λ x-> x ∈ ["MaximalIS", "IndependentSet", "DominatingSet",
                    "MaxCut", "Coloring{3}", "Matching"]),
            "weights"=>Verifier(Vector; optional=true),
            "openvertices"=>Verifier(Vector; default=[]),
            "fixedvertices"=>Verifier(Dict; default=Dict()),
            "cudadevice"=>Verifier(Int; default=-1),
            "optimizer" => VerifierTree(optimizer_verifier(), optional=true),
            "graph" => VerifierTree(graph_verifier())
            )
        )
end