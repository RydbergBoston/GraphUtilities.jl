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

# Better printing
using AbstractTrees

function AbstractTrees.children(ne::VerifierTree)
    [k=>v for (k, v) in ne.dict]
end
AbstractTrees.children(ne::Pair{String, <:VerifierTree}) = children(ne.second)
AbstractTrees.children(ne::Pair{String, <:Verifier}) = []
function AbstractTrees.printnode(io::IO, x::VerifierTree)
    print(io, "ROOT")
    x.optional && print(io, " optional")
end
function AbstractTrees.printnode(io::IO, x::Pair{String, <:VerifierTree})
    print(io, "$(x.first)")
    x.second.optional && print(io, ", optional")
end
function AbstractTrees.printnode(io::IO, x::Pair{String, <:Verifier})
    e = x.second
    print(io, "$(x.first)::$(e.type)")
    print(io, ", checker = ")
    show(io, e.f)
    e.optional && print(io, ", optional")
    e.default isa NoDefault || print(io, ", default = $(e.default)")
end
function Base.show(io::IO, e::VerifierTree)
    print_tree(io, e)
end
Base.show(io::IO, ::MIME"text/plain", e::VerifierTree) = Base.show(io, e)

function verify(tree::VerifierTree, dict)
    updated = Dict()
    # sort the fields for that the dependent fields are updated the last
    kvpairs = [(k,v) for (k, v) in tree.dict]
    sort!(kvpairs, by=x->!isempty(x[2].forfield))
    for (k, v) in kvpairs
        if !isempty(v.forfield)  # check target field
            method = updated[v.forfield]
            if "$(v.forfield).$(method)" != k   # we do not need to extract this conditional field!
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
                :($b.$a) => ("$b.$a", String(b))
                :($a) => ("$a", "")
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
                :($b.$a::$T) => ("$b.$a", T, String(b))
                :($a::$T) => ("$a", T, "")
                :($b.$a) => ("$b.$a", :Any, String(b))
                :($a) => ("$a", :Any, "")
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

const graph_verifier = @terms begin
    nv::Int=@check x->1<=x
    edges::Vector{Vector{Int}}=@check x->all(e->length(e)==2, x)
end

const optimizer_verifier = @terms begin
    method::String = @check x->x ∈ ["TreeSA", "GreedyMethod"] default="GreedyMethod"
    method.TreeSA = @terms begin
        sc_target::Float64 = @check default=20.0
        sc_weight::Float64 = @check default=1.0
        rw_weight::Float64 = @check default=1.0
        ntrials::Int = @check x -> x > 0 default=3
        niters::Int = @check x -> x > 0 default=10
        nslices::Int = @check x-> x>= 0 default=0
        betas::Vector{Float64} = @check x->length(x)>0 default=collect(0.01:0.05:30.0)
    end optional
    method.GreedyMethod = @terms begin
        nrepeat::Int = @check x->length(x)>0 default=10
    end optional
end

const application_verifier = @terms begin
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
        optimizer = @terms $(optimizer_verifier) optional
        graph = @terms $(graph_verifier)
    end
    api.opteinsum = @terms begin
        inputs::Vector{Vector{Int}}=@check
        output::Vector{Int}=@check
        sizes::Dict{Int,Int}=@check
        optimizer = @terms $(optimizer_verifier) optional
        simplifier::String = @check x->x ∈ ["MergeGreedy", "MergeVectors"] optional
    end
    api.graph = @terms begin
        type::String = @check x->x ∈["kings", "square", "regular", "smallgraph"]
        type.kings = @terms begin
            m::Int = @check x->x>0
            n::Int = @check x->x>0
            filling::Float64= @check x->x>0 default=1.0
            seed::Int = @check default=42
        end
        type.square = @terms begin
            m::Int = @check x->x>0
            n::Int = @check x->x>0
            filling::Float64 = @check x->x>0 default=1.0
            seed::Int = @check default=42
        end
        type.smallgraph = @terms begin
            name::String = @check
        end
        type.regular = @terms begin
            d::Int = @check x->x>0
            n::Int = @check x->x>0
            seed::Int = @check default=42
        end
    end
end