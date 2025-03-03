import HTTP
import JSON3
import JSONSchema
using StructTypes
using Dates

export  safe_request,
        safe_request_parse,
        request_parse,
        matches_schema,
        bodyparse,
        typedparser,
        conv

function retryifhttp(_s, e)
  if e isa HTTP.Exceptions.StatusError
    # Only retry if the error status code is in a set of transient errors.
    if e.code in (500, 502, 503, 504)
      @warn "Transient HTTP error ($e). Retrying..."
      return true
    else
      @warn "HTTP error ($e) is not transient. Not retrying."
      return false
    end
  else
    @warn "Non-HTTP exception ($e) occurred. Not retrying."
    return false
  end
end

request_parse(http_args...; parser = JSON3.read) = HTTP.request(http_args...) |> rs -> String(rs.body) |> parser

safe_request(http_args...; delays = ExponentialBackOff(; n = 10)) =
  retry(HTTP.request; check = retryifhttp, delays = delays)(http_args...)

safe_request_parse(http_args...; parser = JSON3.read, delays = ExponentialBackOff(; n = 10)) =
  retry((args...) -> request_parse(args...; parser = parser); check = retryifhttp, delays = delays)(http_args...)

typedjsonread(::Type{T}, json_string) where {T} = JSON3.read(json_string, T)
typedparser(::Type{T}) where {T} = json_string -> typedjsonread(T, json_string)

"Returns `true` iff `x` matches the JSON schema `schema`."
matches_schema(x, schema) = isnothing(JSONSchema.validate(schema, x)) ? true : false

## Conversion
"""
DateTime in format the Rippling ATS API outputs, e.g. "2022-11-18T21:29:15Z"
"""
function rDateTime(x::String)
  formats = [
    dateformat"yyyy-mm-ddTHH:MM:SS-HH:MM",
    dateformat"yyyy-mm-ddTHH:MM:SSZ",
    dateformat"yyyy-mm-ddTHH:MM:SS-HHMM"  # Added just in case the format without the colon in the timezone offset
  ]

  # Add 2023-02-23T22:35:31+06:00 
  formats = vcat(formats, [
    dateformat"yyyy-mm-ddTHH:MM:SS+HH:MM",
    dateformat"yyyy-mm-ddTHH:MM:SS+HHMM"
  ])

  for fmt in formats
    try
      return DateTime(x, fmt)
    catch
      continue
    end
  end

  @warn "Error parsing date $x with all known formats"
  return nothing
end

_conv(x::T, ::Type{T}) where T = x
_conv(x::String, ::Type{DateTime}) = rDateTime(x)
_conv(x::String, ::Type{Bool}) = x == "true"
_conv(x::String, ::Type{T}) where {T<:Number} = parse(T, x)
# Handle missing
nothingstring(x::String) = (x == "null" || x == "")
_conv(x::Nothing, ::Type{Maybe{T}}) where T = nothing
_conv(x::String, ::Type{Maybe{T}}) where T = nothingstring(x) ? nothing : _conv(x, T)
_conv(x, ::Type{T}) where T = conv(x, T)

conv(x::String, ::Type{String}) = x

function conv(j::JSON3.Object, ::Type{Union{Nothing, T}}) where {T}
  if j == nothing
    return nothing
  end
  return conv(j, T)
end

function conv(j::JSON3.Object, ::Type{T}) where {T}
  # e/g/ (:id, :company_id, :company_external_id, :site_id, :site_external_id, :job_title, :job_id, :status,
  # :first_name, :last_name, :phone, :email, :address, :address_2, :city, :state, :country,
  # :zipcode, :rating, :contact_preference, :tags, :system_tags, :applied_at, :hired_at,
  # :start_date, :source, :archived_at, :created_at, :updated_at)
  fn = fieldnames(T)
  ft = fieldtypes(T)

  # @show T
  ks = keys(j)
  fields = []
  # @show j.updated_at
  # @show j.applied_at
  for (f,t)  in zip(fn, ft)
    # @show f, j[f], t
    if f in ks
      try
        res = _conv(j[f], t)
        push!(fields, res)
      catch e
        val = j[f]
        actual_type = typeof(val)
        println("[CONV] Error converting field ``$f'' of type ``$t'' and value ``$val'' and actual type $actual_type: $e, current json: $j")
        flush(stdout)
        throw("[CONV] Error converting field ``$f'' of type ``$t'' and value ``$val'' and actual type $actual_type: $e, current json: $j")
      end
    else # F is not in ks
      try
        res = _conv(nothing, t) # If t is a maybe, this might still be dispatchable
        push!(fields, res)
      catch e
        println("[CONV] Error converting field ``$f'' of type ``$t'' and value ``nothing'': $e, current json: $j")
        flush(stdout)
        throw("[CONV] Error converting field ``$f'' of type ``$t'' and value ``nothing'': $e, current json: $j")
      end
    end
  end
  # @show field_dict
  return T(fields...)::T
end





_conv(j::JSON3.Object, ::Type{<:Dict}) = Dict{Any, Any}(k => v for (k, v) in j)

conv(j::JSON3.Array, ::Type{Vector{T}}) where {T} = map(x -> conv(x, T), j)
conv(x, ::Type{T}) where {T} = T(x)


function conv(j::JSON3.Array, ::Type{T}) where {T}
  error("Array conversion not implemented for type $T")
end
