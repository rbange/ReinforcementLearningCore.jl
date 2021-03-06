export device, send_to_host, send_to_device

using ElasticArrays
using Flux
using CUDA
using Adapt
using Random

import CUDA: device

send_to_host(x) = send_to_device(Val(:cpu), x)
send_to_device(::Val{:cpu}, x) = x  # cpu(x) is not very efficient! So by default we do nothing here.

send_to_device(::Val{:cpu}, x::CuArray) = adapt(Array, x)
send_to_device(::Val{:gpu}, x) = Flux.fmap(a -> adapt(CuArray{Float32}, a), x)

const KnownArrayVariants = Union{
    SubArray{<:Any,<:Any,<:Union{ReservoirArrayBuffer,CircularArrayBuffer,ElasticArray}},
    Base.ReshapedArray{
        <:Any,
        <:Any,
        <:SubArray{
            <:Any,
            <:Any,
            <:Union{ReservoirArrayBuffer,CircularArrayBuffer,ElasticArray},
        },
    },
    Base.ReshapedArray{
        <:Any,
        <:Any,
        <:Union{ReservoirArrayBuffer,CircularArrayBuffer,ElasticArray},
    },
    SubArray{
        <:Any,
        <:Any,
        <:Base.ReshapedArray{
            <:Any,
            <:Any,
            <:SubArray{
                <:Any,
                <:Any,
                <:Union{ReservoirArrayBuffer,CircularArrayBuffer,ElasticArray},
            },
        },
    },
}

# https://github.com/JuliaReinforcementLearning/ReinforcementLearningCore.jl/issues/130
send_to_device(::Val{:cpu}, x::KnownArrayVariants) = Array(x)
send_to_device(::Val{:gpu}, x::Union{KnownArrayVariants,ElasticArray}) = CuArray(x)

"""
    device(model)

Detect the suitable running device for the `model`.
Return `Val(:cpu)` by default.
"""
device(x) = device(Flux.trainable(x))
device(x::Function) = nothing
device(::CuArray) = Val(:gpu)
device(::Array) = Val(:cpu)
device(x::Tuple{}) = nothing
device(x::NamedTuple{(),Tuple{}}) = nothing
device(x::ElasticArray) = device(x.data)

function device(x::Random.AbstractRNG)
    if x isa CUDA.CURAND.RNG
        Val(:gpu)
    else
        Val(:cpu)
    end
end

function device(x::Union{Tuple,NamedTuple})
    d1 = device(x[1])
    if isnothing(d1)
        device(Base.tail(x))
    else
        d1
    end
end

# recoganize Torch.jl
# device(x::Tensor) = Val(Symbol(:gpu, x.device))
