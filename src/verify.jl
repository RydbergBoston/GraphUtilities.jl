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
VerifierTree(pairs::Pair...; optional=false, forfield="") = VerifierTree(Dict(pairs...), optional, forfield)

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
    VerifierTree("nv"=>Verifier(Int, @λ x->1<=x),
        "edges"=>Verifier(Vector{Vector{Int}}, @λ x->all(e->length(e)==2, x)))
end

function optimizer_verifier()
    VerifierTree("method"=>Verifier(String, @λ x->x ∈ ["TreeSA", "GreedyMethod"]; default="GreedyMethod"),
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
    VerifierTree(
        "api"=>Verifier(String, @λ x->x ∈ ["solve", "opteinsum", "graph", "help"]),
        "solve"=> VerifierTree("property"=>Verifier(String, @λ x -> x ∈ ["SizeMax", "SizeMin",
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
            "optimizer" => VerifierTree(optimizer_verifier().dict, optional=true),
            "graph" => VerifierTree(graph_verifier())
            ; forfield="api"),
        "opteinsum"=>VerifierTree(
            "inputs"=>Verifier(Vector{Vector{Int}}),
            "output"=>Verifier(Vector{Int}),
            "optimizer"=>VerifierTree(optimizer_verifier().dict, optional=true),
            "simplifier"=>Verifier(String, (@λ x->x ∈ ["MergeGreedy", "MergeVectors"]), optional=true)
            ),
        "graph"=>VerifierTree(
            "name"=>Verifier(String, @λ x->x ∈ ["kings", "square", "smallgraph", "regular"]),
            "kings"=>VerifierTree("m"=>Verifier(Int, @λ x->x>0))
        )
    )
end

using MLStyle

macro terms(args...)
    terms_impl(args...)
end

function terms_impl(args...)
    x, verifier = verifier_impl(:(x = @terms $(args...)))
    return verifier
end

function verifier_impl(expr)
    @match expr begin
        :($x = @terms $line $body $(kwi...)) => begin
            sym, forfield = @match x begin
                :($b.$a) => (String(a), String(b))
                :($a) => (String(a), "")
            end
            optional = false
            for arg in kwi
                @match arg begin
                    :(optional) => (optional = true)
                end
            end
            @match body begin
                :(begin $(args...) end) => begin
                    keys = String[]
                    vals = []
                    for arg in args
                        arg isa LineNumberNode && continue
                        k, v = verifier_impl(arg)
                        push!(keys, String(k))
                        push!(vals, v)
                    end
                    ex = :($VerifierTree($([:($k=>$v) for (k, v) in zip(keys, vals)]...); optional=$optional, forfield=$forfield))
                    sym, ex
                end
                Expr(:$, subexpr) => begin
                    sym, :($VerifierTree($subexpr.dict; optional=$optional, forfield=$forfield))
                end
            end
        end
        :($x = @check $line $(args...)) => begin
            sym, type, forfield = @match x begin
                :($b.$a::$T) => (String(a), T, String(b))
                :($a::$T) => (String(a), T, "")
                :($b.$a) => (String(a), :Any, String(b))
                :($a) => (String(a), :Any, "")
            end
            f, optional, default = :(x->true), false, NoDefault()
            for arg in args
                @match arg begin
                    Expr(:(->), a, b) => (f = arg)
                    :(optional) => (optional = true)
                    :(default = $val) => (default = val)
                end
            end
            lambda = LegibleLambdas.parse_lambda(f)
            ex = :($Verifier($type, $lambda; default=$default, optional=$optional, forfield=$forfield))
            sym, ex
        end
    end
end

pvr = @terms begin
    api::String = @check x->x∈["solve", "opteinsum", "graph", "help"]
    api.solve = @terms begin
        property::String = @check x -> x ∈ ["SizeMax", "SizeMin",
            "SizeMax3", "SizeMin3", "CountingAll",
            "CountingMax", "CountingMin", "CountingMax3", "CountingMin3", "GraphPolynomial",
            "SingleConfigMax", "SingleConfigMin", "SingleConfigMax3", "SingleConfigMin3",
            "ConfigsMaxTree", "ConfigsMin",
            "ConfigsMaxTree3", "ConfigsMin3",
            "ConfigsAll", "ConfigsAllTree"
            ]
        problem::String = @check x -> x ∈ ["MaximalIS", "IndependentSet", "DominatingSet",
                "MaxCut", "Coloring{3}", "Matching"]
        weights::Vector = @check optional
        openvertices::Vector = @check default=[]
        fixedvertices::Dict = @check default=Dict()
        cudadevice::Int = @check default=-1
        optimizer = @terms $(optimizer_verifier()) optional
        graph = @terms $(graph_verifier())
    end
    api.opteinsum = @terms begin
        inputs::Vector{Vector{Int}}=@check
        output::Vector{Int}=@check
        optimizer = @terms $(optimizer_verifier()) optional
        simplifier::String = @check x->x ∈ ["MergeGreedy", "MergeVectors"] optional
    end
    api.graph = @terms begin
        type::String = @check x->x ∈["kings", "square", "regular", "smallgraph"]
        type.kings = @terms begin
            m::Int = @check x->x>0
            n::Int = @check x->x>0
            filling::Float64= @check x->x>0
            seed::Int = @check
        end
        type.square = @terms begin
            m::Int = @check x->x>0
            n::Int = @check x->x>0
            filling::Float64 = @check x->x>0
        end
        type.smallgraph = @terms begin
            name::String = @check
        end
        type.regular = @terms begin
            d::Int = @check x->x>0
            n::Int = @check x->x>0
            seed::Int = @check
        end
    end
end