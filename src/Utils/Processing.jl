# Part of submodule Utils of BetaML - The Beta Machine Learning Toolkit
# Functions typically used for processing (manipulating) data, typically preprocessing data before running a ML model


# ------------------------------------------------------------------------------
# Various reshaping functions
import Base.reshape
""" reshape(myNumber, dims..) - Reshape a number as a n dimensional Array """
reshape(x::T, dims...) where {T <: Number} =   (x = [x]; reshape(x,dims) )
makeColVector(x::T) where {T} =  [x]
makeColVector(x::T) where {T <: AbstractArray} =  reshape(x,length(x))
makeRowVector(x::T) where {T <: Number} = return [x]'
makeRowVector(x::T) where {T <: AbstractArray} =  reshape(x,1,length(x))
"""Transform an Array{T,1} in an Array{T,2} and leave unchanged Array{T,2}."""
makeMatrix(x::AbstractArray) = ndims(x) == 1 ? reshape(x, (size(x)...,1)) : x


"""Return wheather an array is sortable, i.e. has methos issort defined"""
issortable(::AbstractArray{T,N})  where {T,N} = hasmethod(isless, Tuple{nonmissingtype(T),nonmissingtype(T)})


"""
    getPermutations(v::AbstractArray{T,1};keepStructure=false)

Return a vector of either (a) all possible permutations (uncollected) or (b) just those based on the unique values of the vector

Useful to measure accuracy where you don't care about the actual name of the labels, like in unsupervised classifications (e.g. clustering)

"""
function getPermutations(v::AbstractArray{T,1};keepStructure=false) where {T}
    if !keepStructure
        return Combinatorics.permutations(v)
    else
        classes       = unique(v)
        nCl           = length(classes)
        N             = size(v,1)
        pSet          = Combinatorics.permutations(1:nCl)
        nP            = length(pSet)
        vPermutations = fill(similar(v),nP)
        vOrigIdx      = [findfirst(x -> x == v[i] , classes) for i in 1:N]
        for (pIdx,perm) in enumerate(pSet)
            vPermutations[pIdx] = classes[perm[vOrigIdx]] # permuted specific version
        end
        return vPermutations
    end
end


""" singleUnique(x) Return the unique values of x whether x is an array of arrays, an array or a scalar"""
function singleUnique(x::Union{T,AbstractArray{T}}) where {T <: Union{Any,AbstractArray{T2}} where T2 <: Any }
    if typeof(x) <: AbstractArray{T2} where {T2 <: AbstractArray}
        return unique(vcat(unique.(x)...))
    elseif typeof(x) <: AbstractArray{T2} where {T2}
        return unique(x)
    else
        return [x]
    end
end

function oneHotEncoderRow(x::Union{AbstractArray{T},T}; d=maximum(x), factors=1:d,count = false) where {T <: Integer}
    x = makeColVector(x)
    out = zeros(Int64,d)
    for j in x
        out[j] = count ? out[j] + 1 : 1
    end
    return out
end

function oneHotEncoderRow(x::Union{AbstractArray{T},T};factors=singleUnique(x),d=length(factors),count = false) where {T}
    x = makeColVector(x)
    return oneHotEncoderRow(integerEncoder(x;factors=factors),d=length(factors);count=count)
end

"""
    oneHotEncoder(x;d,factors,count)

Encode arrays (or arrays of arrays) of categorical data as matrices of one column per factor.

The case of arrays of arrays is for when at each record you have more than one categorical output. You can then decide to encode just the presence of the factors or their counting

# Parameters:
- `x`: The data to convert (array or array of arrays)
- `d`: The number of dimensions in the output matrix [def: `maximum(x)` for integers and `length(factors)` otherwise]
- `factors`: The factors from which to encode [def: `1:d` for integer x or `unique(x)` otherwise]
- `count`: Wether to count multiple instances on the same dimension/record (`true`) or indicate just presence. [def: `false`]

# Examples
```julia
julia> oneHotEncoder(["a","c","c"],factors=["a","b","c","d"])
3×4 Matrix{Int64}:
 1  0  0  0
 0  0  1  0
 0  0  1  0
julia> oneHotEncoder([2,4,4])
3×4 Matrix{Int64}:
 0  1  0  0
 0  0  0  1
 0  0  0  1
 julia> oneHotEncoder([[2,2,1],[2,4,4]],count=true)
2×4 Matrix{Int64}:
 1  2  0  0
 0  1  0  2
```
"""
function oneHotEncoder(x::Union{T,AbstractVector{T}};factors=singleUnique(x),d=length(factors),count=false) where {T <: Union{Any,AbstractVector{T2}} where T2 <: Any  }
    if typeof(x) <: AbstractVector
        n  = length(x)
        out = zeros(Int64,n,d)
        for (i,x) in enumerate(x)
          out[i,:] = oneHotEncoderRow(x;factors=factors,count = count)
        end
        return out
    else
       out = zeros(Int64,1,d)
       out[1,:] = oneHotEncoderRow(x;factors=factors,count = count)
       return out
   end
end

function oneHotEncoder(Y::Union{Ti,AbstractVector{Ti}};d=maximum(maximum.(Y)),factors=1:d,count=false) where {Ti <: Union{Integer,AbstractVector{Ti2}} where Ti2 <: Integer  }
    n   = length(Y)
    if d < maximum(maximum.(Y))
        error("Trying to encode elements with indexes greater than the provided number of dimensions. Please increase d.")
    end
    out = zeros(Int64,n,d)
    for (i,y) in enumerate(Y)
        out[i,:] = oneHotEncoderRow(y;d=d,factors=1:d,count = count)
    end
    return out
end

findfirst(el::T,cont::Array{T};returnTuple=true) where {T<:Union{AbstractString,Number}} = ndims(cont) > 1 && returnTuple ? Tuple(findfirst(x -> isequal(x,el),cont)) : findfirst(x -> isequal(x,el),cont)
#findfirst(el::T,cont::Array{T,N};returnTuple=true) where {T,N} = returnTuple ? Tuple(findfirst(x -> isequal(x,el),cont)) : findfirst(x -> isequal(x,el),cont)
#findfirst(el::T,cont::Array{T,1};returnTuple=true) where {T} =  findfirst(x -> isequal(x,el),cont)


findall(el::T, cont::Array{T};returnTuple=true) where {T} = ndims(cont) > 1 && returnTuple ? Tuple.(findall(x -> isequal(x,el),cont)) : findall(x -> isequal(x,el),cont)

"""
    integerEncoder(x;factors=unique(x))

Encode an array of T to an array of integers using the their position in `factor` vector (default to the unique vector of the input array)

# Parameters:
- `x`: The vector to encode
- `factors`: The vector of factors whose position is the result of the encoding [def: `unique(x)`]
# Return:
- A vector of [1,length(x)] integers corresponding to the position of each element in the `factors` vector`
# Note:
- Attention that while this function creates a ordered (and sortable) set, it is up to the user to be sure that this "property" is not indeed used in his code if the unencoded data is indeed unordered.
# Example:
```
julia> integerEncoder(["a","e","b","e"],factors=["a","b","c","d","e"]) # out: [1,5,2,5]
```
"""
function integerEncoder(x::AbstractVector;factors=Base.unique(x))
    #return findfirst.(x,Ref(factors)) slower
    return  map(i -> findfirst(j -> j==i,factors) , x  )
end

"""
    integerDecoder(x,factors::AbstractVector{T};unique)

Decode an array of integers to an array of T corresponding to the elements of `factors`

# Parameters:
- `x`: The vector to decode
- `factors`: The vector of elements to use for the encoding
- `unique`: Wether `factors` is already made of unique elements [def: `true`]
# Return:
- A vector of length(x) elements corresponding to the (unique) `factors` elements at the position x
# Example:
```
julia> integerDecoder([1, 2, 2, 3, 2, 1],["aa","cc","bb"]) # out: ["aa","cc","cc","bb","cc","aa"]
```
"""
function integerDecoder(x,factors::AbstractVector{T};unique=true) where{T}
    uniqueTarget =  unique ? factors :  Base.unique(factors)
    return map(i -> uniqueTarget[i], x )
end



"""
    partition(data,parts;shuffle,dims,rng)

Partition (by rows) one or more matrices according to the shares in `parts`.

# Parameters
* `data`: A matrix/vector or a vector of matrices/vectors
* `parts`: A vector of the required shares (must sum to 1)
* `shufle`: Whether to randomly shuffle the matrices (preserving the relative order between matrices)
* `dims`: The dimension for which to partition [def: `1`]
* `copy`: Wheter to _copy_ the actual data or only create a reference [def: `true`]
* `rng`: Random Number Generator (see [`FIXEDSEED`](@ref)) [deafult: `Random.GLOBAL_RNG`]

# Notes:
* The sum of parts must be equal to 1
* The number of elements in the specified dimension must be the same for all the arrays in `data`

# Example:
```julia
julia> x = [1:10 11:20]
julia> y = collect(31:40)
julia> ((xtrain,xtest),(ytrain,ytest)) = partition([x,y],[0.7,0.3])
 ```
 """
function partition(data::AbstractArray{T,1},parts::AbstractArray{Float64,1};shuffle=true,dims=1,copy=true,rng = Random.GLOBAL_RNG) where T <: AbstractArray
        # the sets of vector/matrices
        N = size(data[1],dims)
        all(size.(data,dims) .== N) || @error "All matrices passed to `partition` must have the same number of elements for the required dimension"
        ridx = shuffle ? Random.shuffle(rng,1:N) : collect(1:N)
        return partition.(data,Ref(parts);shuffle=shuffle,dims=dims,fixedRIdx = ridx,copy=copy,rng=rng)
end

function partition(data::AbstractArray{T,Ndims}, parts::AbstractArray{Float64,1};shuffle=true,dims=1,fixedRIdx=Int64[],copy=true,rng = Random.GLOBAL_RNG) where {T,Ndims}
    # the individual vector/matrix
    N        = size(data,dims)
    nParts   = size(parts)
    toReturn = toReturn = Array{AbstractArray{T,Ndims},1}(undef,nParts)
    if !(sum(parts) ≈ 1)
        @error "The sum of `parts` in `partition` should total to 1."
    end
    ridx = fixedRIdx
    if (isempty(ridx))
       ridx = shuffle ? Random.shuffle(rng, 1:N) : collect(1:N)
    end
    allDimIdx = convert(Vector{Union{UnitRange{Int64},Vector{Int64}}},[1:i for i in size(data)])
    current = 1
    cumPart = 0.0
    for (i,p) in enumerate(parts)
        cumPart += parts[i]
        final = i == nParts ? N : Int64(round(cumPart*N))
        allDimIdx[dims] = ridx[current:final]
        toReturn[i]     = copy ? data[allDimIdx...] : @views data[allDimIdx...]
        current         = (final +=1)
    end
    return toReturn
end




"""
    getScaleFactors(x;skip)

Return the scale factors (for each dimensions) in order to scale a matrix X (n,d)
such that each dimension has mean 0 and variance 1.

# Parameters
- `x`: the (n × d) dimension matrix to scale on each dimension d
- `skip`: an array of dimension index to skip the scaling [def: `[]`]

# Return
- A touple whose first elmement is the shift and the second the multiplicative
term to make the scale.
"""
function getScaleFactors(x;skip=[])
    μ  = mean(x,dims=1)
    σ² = var(x,corrected=false,dims=1)
    sfμ = - μ
    sfσ² = 1 ./ sqrt.(σ²)
    for i in skip
        sfμ[i] = 0
        sfσ²[i] = 1
    end
    return (sfμ,sfσ²)
end

"""
    scale(x,scaleFactors;rev)

Perform a linear scaling of x using scaling factors `scaleFactors`.

# Parameters
- `x`: The (n × d) dimension matrix to scale on each dimension d
- `scalingFactors`: A tuple of the constant and multiplicative scaling factor
respectively [def: the scaling factors needed to scale x to mean 0 and variance 1]
- `rev`: Whether to invert the scaling [def: `false`]

# Return
- The scaled matrix

# Notes:
- Also available `scale!(x,scaleFactors)` for in-place scaling.
- Retrieve the scale factors with the `getScaleFactors()` function
"""
function scale(x,scaleFactors=(-mean(x,dims=1),1 ./ sqrt.(var(x,corrected=false,dims=1))); rev=false )
    if (!rev)
      y = (x .+ scaleFactors[1]) .* scaleFactors[2]
    else
      y = (x ./ scaleFactors[2]) .- scaleFactors[1]
    end
    return y
end
function scale!(x,scaleFactors=(-mean(x,dims=1),1 ./ sqrt.(var(x,corrected=false,dims=1))); rev=false)
    if (!rev)
        x .= (x .+ scaleFactors[1]) .* scaleFactors[2]
    else
        x .= (x ./ scaleFactors[2]) .- scaleFactors[1]
    end
    return nothing
end

"""
pca(X;K,error)

Perform Principal Component Analysis returning the matrix reprojected among the dimensions of maximum variance.

# Parameters:
- `X` : The (N,D) data to reproject
- `K` : The number of dimensions to maintain (with K<=D) [def: `nothing`]
- `error`: The maximum approximation error that we are willing to accept [def: `0.05`]

# Return:
- A named tuple with:
  - `X`: The reprojected (NxK) matrix with the column dimensions organized in descending order of of the proportion of explained variance
  - `K`: The number of dimensions retieved
  - `error`: The actual proportion of variance not explained in the reprojected dimensions
  - `P`: The (D,K) matrix of the eigenvectors associated to the K-largest eigenvalues used to reproject the data matrix
  - `explVarByDim`: An array of dimensions D with the share of the cumulative variance explained by dimensions (the last element being always 1.0)

# Notes:
- If `K` is provided, the parameter `error` has no effect.
- If one doesn't know _a priori_ the error that she/he is willling to accept, nor the wished number of dimensions, he/she can run this pca function with `out = pca(X,K=size(X,2))` (i.e. with K=D), analise the proportions of explained cumulative variance by dimensions in `out.explVarByDim`, choose the number of dimensions K according to his/her needs and finally pick from the reprojected matrix only the number of dimensions needed, i.e. `out.X[:,1:K]`.

# Example:
```julia
julia> X = [1 10 100; 1.1 15 120; 0.95 23 90; 0.99 17 120; 1.05 8 90; 1.1 12 95]
6×3 Matrix{Float64}:
 1.0   10.0  100.0
 1.1   15.0  120.0
 0.95  23.0   90.0
 0.99  17.0  120.0
 1.05   8.0   90.0
 1.1   12.0   95.0
julia> X = pca(X,error=0.05).X
6×2 Matrix{Float64}:
 100.449    3.1783
 120.743    6.80764
  91.3551  16.8275
 120.878    8.80372
  90.3363   1.86179
  95.5965   5.51254
```

"""
function pca(X;K=nothing,error=0.05)
    # debug
    #X = [1 10 100; 1.1 15 120; 0.95 23 90; 0.99 17 120; 1.05 8 90; 1.1 12 95]
    #K = nothing
    #error=0.05

    (N,D) = size(X)
    if !isnothing(K) && K > D
        @error("The parameter K must be ≤ D")
    end
    Σ = (1/N) * X'*(I-(1/N)*ones(N)*ones(N)')*X
    E = eigen(Σ) # eigenvalues are ordered from the smallest to the largest
    totVar  = sum(E.values)
    explVarByDim = [sum(E.values[D-k+1:end])/totVar for k in 1:D]
    propVarExplained = 0.0
    if K == nothing
        for k in 1:D
            if explVarByDim[k] >= (1 - error)
                propVarExplained  = explVarByDim[k]
                K                 = k
                break
            end
        end
    else
        propVarExplained = explVarByDim[K]
    end

    P = E.vectors[:,end:-1:D-K+1] # bug corrected 2/9/2021

    return (X=X*P,K=K,error=1-propVarExplained,P=P,explVarByDim=explVarByDim)
end


"""
    colsWithMissing(x)

Retuyrn an array with the ids of the columns where there is at least a missing value.
"""
function colsWithMissing(x)
    colsWithMissing = Int64[]
    (N,D) = size(x)
    for d in 1:D
        for n in 1:N
            if ismissing(x[n,d])
                push!(colsWithMissing,d)
                break
            end
        end
    end
    return colsWithMissing
end

"""
    crossValidation(f,data,sampler;dims,verbosity,returnStatistics)

Perform crossValidation according to `sampler` rule by calling the function f and collecting its output

# Parameters
- `f`: The user-defined function that consume the specific train and validation data and return somehting (often the associated validation error). See later
- `data`: A single n-dimenasional array or a vector of them (e.g. X,Y), depending on the tasks required by `f`.
- sampler: An istance of a ` AbstractDataSampler`, defining the "rules" for sampling at each iteration. [def: `KFold(nSplits=5,nRepeats=1,shuffle=true,rng=Random.GLOBAL_RNG)` ]
- `dims`: The dimension over performing the crossValidation i.e. the dimension containing the observations [def: `1`]
- `verbosity`: The verbosity to print information during each iteration (this can also be printed in the `f` function) [def: `STD`]
- `returnStatistics`: Wheter crossValidation should return the statistics of the output of `f` (mean and standard deviation) or the whole outputs [def: `true`].

# Notes

crossValidation works by calling the function `f`, defined by the user, passing to it the tuple `trainData`, `valData` and `rng` and collecting the result of the function f. The specific method for which `trainData`, and `valData` are selected at each iteration depends on the specific `sampler`, whith a single 5 k-fold rule being the default.

This approach is very flexible because the specific model to employ or the metric to use is left within the user-provided function. The only thing that crossValidation does is provide the model defined in the function `f` with the opportune data (and the random number generator).

**Input of the user-provided function**
`trainData` and `valData` are both themselves tuples. In supervised models, crossValidations `data` should be a tuple of (X,Y) and `trainData` and `valData` will be equivalent to (xtrain, ytrain) and (xval, yval). In unsupervised models `data` is a single array, but the training and validation data should still need to be accessed as  `trainData[1]` and `valData[1]`.
**Output of the user-provided function**
The user-defined function can return whatever. However, if `returnStatistics` is left on its default `true` value the user-defined function must return a single scalar (e.g. some error measure) so that the mean and the standard deviation are returned.

Note that `crossValidation` can beconveniently be employed using the `do` syntax, as Julia automatically rewrite `crossValidation(data,...) trainData,valData,rng  ...user defined body... end` as `crossValidation(f(trainData,valData,rng ), data,...)`

# Example

```
julia> X = [11:19 21:29 31:39 41:49 51:59 61:69];
julia> Y = [1:9;];
julia> sampler = KFold(nSplits=3);
julia> (μ,σ) = crossValidation([X,Y],sampler) do trainData,valData,rng
                 (xtrain,ytrain) = trainData; (xval,yval) = valData
                 trainedModel    = buildForest(xtrain,ytrain,30)
                 predictions     = predict(trainedModel,xval)
                 ϵ               = meanRelError(predictions,yval,normRec=false)
                 return ϵ
               end
(0.3202242202242202, 0.04307662219315022)
```

"""
function crossValidation(f,data,sampler=KFold(nSplits=5,nRepeats=1,shuffle=true,rng=Random.GLOBAL_RNG);dims=1,verbosity=STD, returnStatistics=true)
    iterResults = []
    for (i,iterData) in enumerate(SamplerWithData(sampler,data,dims))
       iterResult = f(iterData[1],iterData[2],sampler.rng)
       push!(iterResults,iterResult)
       if verbosity > STD
           println("Done iteration $i. This iteration output: $iterResult")
       end
    end
    if returnStatistics  return (mean(iterResults),std(iterResults)) else return iterResults end
end

#= TODO
abstract type ParametersSet

        
Base.@kwdef struct NNModelParametersSet <: ParametersSet
  neuronsRange::Vector{Int64}   = 6:4:12
  epochesRange::Vector{Int64}   = 200:100:300
  batchSizeRange::Vector{Int64} = 4:2:6
end
function tuneHyperParameters(model,Pset::ParameterSet,xtrain,ytrain;neuronsRange=6:4:12,epochesRange= 200:100:300:size(xtrain,2),batchSizeRange = 4:2:6,repetitions=5,rng=Random.GLOBAL_RNG) 

=#



"""
   classCountsWithLabels(x)

Return a dictionary that counts the number of each unique item (rows) in a dataset.

"""
function classCountsWithLabels(x;classes=nothing)
    dims = ndims(x)
    if dims == 1
        T = eltype(x)
    else
        T = Array{eltype(x),1}
    end
    if classes != nothing
        counts = Dict([u=>0 for u in classes])
    else
        counts = Dict{T,Int64}()  # a dictionary of label -> count.
    end
    for i in 1:size(x,1)
        if dims == 1
            label = x[i]
        else
            label = x[i,:]
        end
        if !(label in keys(counts))
            counts[label] = 1
        else
            counts[label] += 1
        end
    end
    return counts
end

"""
   classCounts(x;classes=nothing)

Return a (unsorted) vector with the counts of each unique item (element or rows) in a dataset.

If order is important or not all classes are present in the data, a preset vectors of classes can be given in the parameter `classes`

"""
function classCounts(x; classes=nothing)
   if classes == nothing # order doesn't matter
      return values(classCountsWithLabels(x;classes=classes))
   else
       cWithLabels = classCountsWithLabels(x;classes=classes)
       return [cWithLabels[k] for k in classes]
   end
end






"""
   mode(dict::Dict{T,Float64};rng)

Return the key with highest mode (using rand in case of multimodal values)

"""
function mode(dict::Dict{T,Float64};rng = Random.GLOBAL_RNG) where {T}
    mks = [k for (k,v) in dict if v==maximum(values(dict))]
    if length(mks) == 1
        return mks[1]
    else
        return mks[rand(rng,1:length(mks))]
    end
end

"""
   mode(v::AbstractVector{T};rng)

Return the position with the highest mode (using rand in case of multimodal values)

"""
function mode(v::AbstractVector{T};rng = Random.GLOBAL_RNG) where {T <: Number}
    mpos = findall(x -> x == maximum(v),v)
    if length(mpos) == 1
        return mpos[1]
    else
        return mpos[rand(rng,1:length(mpos))]
    end
end


"""
  mode(elements,rng)

Given a vector of dictionaries whose key is numerical (e.g. probabilities), a vector of vectors or a matrix, it returns the mode of each element (dictionary, vector or row) in terms of the key or the position.

Use it to return a unique value from a multiclass classifier returning probabilities.

# Note:
- If multiple classes have the highest mode, one is returned at random (use the parameter `rng` to fix the stochasticity)

"""
function mode(dicts::AbstractArray{Dict{T,Float64}};rng = Random.GLOBAL_RNG) where {T}
    return mode.(dicts;rng=rng)
end

function mode(vals::AbstractArray{T,1};rng = Random.GLOBAL_RNG) where {T <: AbstractArray{T2,1} where T2 <: Number}
    return mode.(vals;rng=rng)
end
function mode(vals::AbstractArray{T,2};rng = Random.GLOBAL_RNG) where {T <: Number}
    return [mode(r;rng=rng) for r in eachrow(vals)]
end


"""
   meanDicts(dicts)

Compute the mean of the values of an array of dictionaries.

Given `dicts` an array of dictionaries, `meanDicts` first compute the union of the keys and then average the values.
If the original valueas are probabilities (non-negative items summing to 1), the result is also a probability distribution.

"""
function meanDicts(dicts; weights=ones(length(dicts)))
    if length(dicts) == 1
        return dicts[1]
    end
    T = eltype(keys(dicts[1]))
    allkeys = union([keys(i) for i in dicts]...)
    outDict = Dict{T,Float64}()
    ndicts = length(dicts)
    totWeights = sum(weights)
    for k in allkeys
        v = 0
        for (i,d) in enumerate(dicts)
            if k in keys(d)
                v += (d[k])*(weights[i]/totWeights)
            end
        end
        outDict[k] = v
    end

    return outDict
end

# ------------------------------------------------------------------------------
# Other mathematical/computational functions

""" LogSumExp for efficiently computing log(sum(exp.(x))) """
lse(x) = maximum(x)+log(sum(exp.(x .- maximum(x))))
""" Sterling number: number of partitions of a set of n elements in k sets """
sterling(n::BigInt,k::BigInt) = (1/factorial(k)) * sum((-1)^i * binomial(k,i)* (k-i)^n for i in 0:k)
sterling(n::Int64,k::Int64)   = sterling(BigInt(n),BigInt(k))
