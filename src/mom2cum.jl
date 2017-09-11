"""
  outer!(z::Vector{Float}, a::Vector{Float}, b::Vector{Float})

Return z - Vector{Float} , vectorsed outer/kroneker product o vectors a and b
Auxiliary function for rawmoment
"""
function outer!{T <: AbstractFloat}(z::Vector{T}, a::Vector{T}, b::Vector{T})
    sa = size(a,1)
    sb = size(b,1)
    m = 1
    for i = 1:sb for j = 1:sa
        @inbounds z[m] = a[j]*b[i]
        m += 1
    end
    end
end

"""
  updvec!(A::Vector{Float}, B::Vector{Float})

Returns updated Vector{Float} A, by adding elementwisely Vector{Float} B
Auxiliary function for rawmoment
"""
function updvec!{T<: AbstractFloat}(A::Vector{T}, B::Vector{T})
  n = size(A, 1)
  for i=1:n
    @inbounds A[i] += B[i]
  end
  return A
end

"""
  rawmoment(X::Matrix{T}, m::Int = 4)

Simmilar to raw_moments_upto_p in R, does not expoloit tensor's symmetry
pyramid structures and blocks

Returns Array{Float, m}, the m'th moment's tensor
"""

function rawmoment{T <: AbstractFloat}(X::Matrix{T}, m::Int = 4)
  t,n = size(X)
  if m == 1
    return mean(X, 1)[1,:]
  else
    z = [map(i -> zeros(T, n^i), 1:m)...]
    y = zeros(T, n^m)
    for i in 1:t
      xi = X[i, :]
      z[1] = xi
      for j in 2:m
        outer!(z[j], xi, z[j-1])
      end
      updvec!(y, z[m])
    end
  end
  reshape(y/t, fill(n, m)...)
end

"""
  raw_moments_upto_k(X::Matrix, k::Int = 4)

Returns [Array{Float, 1}, ..., Array{Float, k}] noncentral moment tensors of
order 1, ..., k
"""
raw_moments_upto_k{T <: AbstractFloat}(X::Matrix{T}, k::Int = 4) =
  [rawmoment(X, i) for i in 1:k]

"""
  cumulants_from_moments(raw::Vector{Array{Float, i}, m = 1:k})

Returns [Array{Float, 1}, ..., Array{Float, k}] cumulant tensors of order 1, ..., k

Uses relation between cumulants and multivariate moments from e.g.
c_{ijkl} = m_{ijkl} - m_{ijk} m_{l} [4] - m_{ij} m_{kl} [3] + 2 m_{ij} m_{k} m_{l}
-6 m_{i} m_{j} m_{k} m_{l}
"""

function cumulants_from_moments{T <: AbstractFloat}(raw::Vector{Array{T}})
  k = length(raw)
  #cumarr = Array(Array{Float64}, k)
  cumarr = Array{Array{Float64}}(k)
  for j in 1:k
    dimr = size(raw[j])
    cumu = zeros(Float64, dimr)
    ldim = length(dimr)
    spp = collect(partitions(1:ldim))
    qpp = [(-1)^i*factorial(i) for i in 0:(ldim-1)]
    sppl = [map(length, spp[i]) for i in 1:length(spp)]
    for i in 1:prod(dimr)
      @inbounds ind = ind2sub(dimr, i)
      @inbounds cumu[ind...] = onecumulant(ind, raw, spp, sppl, qpp)
    end
    cumarr[j] = cumu
  end
  cumarr
end

"""
  onecumulant(ind::Tuple, raw::Vector{Array}, spp::Vector, sppl::Vector{Vector}, dpp::Vector)

raw - vector of moment's tensors, spp - vector of partitions, sppl - vector of sizes of partitions
dpp - vector of a factor for each product of moments (a factorial factor).

Returns Array{Float, n} the n'th cumulant tensor

"""
function onecumulant{T <: AbstractFloat}(ind::Tuple, raw::Vector{Array{T}},
  spp::Vector, sppl::Vector{Vector{Int}}, dpp::Vector{Int})
  ret = zero(T)
  for i in 1:length(spp)
    part = spp[i]
    beln = length(part)
    k = sppl[i]
    temp = one(T)
    for r in 1:beln
      temp *= raw[k[r]][ind[part[r]]...]
    end
    ret += dpp[beln]*temp
  end
  ret
end


"""
  cumulatsfrommoments(x::Matrix{Float}, k::Int)

Returns a vector of 1,2, .., k dims Arrays{Float} of cumulant tensors
"""
mom2cums{T <: AbstractFloat}(x::Matrix{T}, k::Int) =
  cumulants_from_moments(raw_moments_upto_k(x, k))
