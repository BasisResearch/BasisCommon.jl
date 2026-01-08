using Test
using BasisCommon
using JSON3
using Dates

const _JET_AVAILABLE = Base.find_package("JET") !== nothing
if _JET_AVAILABLE
    using JET
end

struct SimpleConv
    id::Int
    name::String
    active::Bool
end

struct WithOptional
    id::Int
    note::Maybe{String}
    count::Maybe{Int}
end

struct WithNumbers
    count::Int
    ratio::Float64
end

struct Address
    street::String
    city::String
    zipcode::Int
end

struct Preferences
    theme::Maybe{String}
    retries::Int
end

struct UserProfile
    id::Int
    name::String
    address::Address
    tags::Vector{String}
    prefs::Maybe{Preferences}
    created_at::DateTime
end

struct Team
    name::String
    members::Vector{UserProfile}
end

struct WithDict
    meta::Dict{Any, Any}
end

readjson(json::AbstractString) = JSON3.read(json)

@testset "conv flat struct" begin
    j = readjson("""{"id": 1, "name": "Alice", "active": true}""")
    res = BasisCommon.conv(j, SimpleConv)
    @test res.id == 1
    @test res.name == "Alice"
    @test res.active == true
end

@testset "conv optional fields" begin
    j = readjson("""{"id": 2, "note": null, "count": "42"}""")
    res = BasisCommon.conv(j, WithOptional)
    @test res.id == 2
    @test res.note === nothing
    @test res.count == 42
    j_missing = readjson("""{"id": 3}""")
    res_missing = BasisCommon.conv(j_missing, WithOptional)
    @test res_missing.id == 3
    @test res_missing.note === nothing
    @test res_missing.count === nothing
end

@testset "conv numbers from strings" begin
    j = readjson("""{"count": "7", "ratio": 0.25}""")
    res = BasisCommon.conv(j, WithNumbers)
    @test res.count == 7
    @test res.ratio == 0.25
end

@testset "conv nested structs and arrays" begin
    j = readjson("""
    {
        "id": 10,
        "name": "Pat",
        "address": {"street": "Main", "city": "NYC", "zipcode": 10001},
        "tags": ["a", "b"],
        "prefs": {"theme": "dark", "retries": 3},
        "created_at": "2022-11-18T21:29:15Z"
    }
    """)
    expected_time = DateTime("2022-11-18T21:29:15Z", dateformat"yyyy-mm-ddTHH:MM:SSZ")
    res = BasisCommon.conv(j, UserProfile)
    @test res.id == 10
    @test res.name == "Pat"
    @test res.address.street == "Main"
    @test res.address.city == "NYC"
    @test res.address.zipcode == 10001
    @test res.tags == ["a", "b"]
    @test res.prefs !== nothing
    @test res.prefs.theme == "dark"
    @test res.prefs.retries == 3
    @test res.created_at == expected_time
end

@testset "conv nested optional object and vector of structs" begin
    j = readjson("""
    {
        "name": "Eng",
        "members": [
            {
                "id": 11,
                "name": "Kim",
                "address": {"street": "Oak", "city": "SF", "zipcode": 94107},
                "tags": [],
                "created_at": "2022-11-18T21:29:15Z"
            },
            {
                "id": 12,
                "name": "Lee",
                "address": {"street": "Pine", "city": "LA", "zipcode": 90001},
                "tags": ["x"],
                "prefs": {"theme": null, "retries": 1},
                "created_at": "2022-11-18T21:29:15Z"
            }
        ]
    }
    """)
    t = BasisCommon.conv(j, Team)
    @test t.name == "Eng"
    @test length(t.members) == 2
    @test t.members[1].prefs === nothing
    @test t.members[2].prefs !== nothing
    @test t.members[2].prefs.theme === nothing
    @test t.members[2].prefs.retries == 1
end

@testset "conv JSON array to vector" begin
    j = readjson("""[
        {"id": 1, "name": "A", "active": false},
        {"id": 2, "name": "B", "active": true}
    ]""")
    res = BasisCommon.conv(j, Vector{SimpleConv})
    @test length(res) == 2
    @test res[1].id == 1
    @test res[1].name == "A"
    @test res[1].active == false
    @test res[2].id == 2
    @test res[2].name == "B"
    @test res[2].active == true
end

@testset "conv dict field" begin
    j = readjson("""{"meta": {"key": "value", "count": 2}}""")
    res = BasisCommon.conv(j, WithDict)
    key_sym = haskey(res.meta, :key) ? :key : "key"
    count_sym = haskey(res.meta, :count) ? :count : "count"
    @test res.meta[key_sym] == "value"
    @test res.meta[count_sym] == 2
end

@testset "conv missing required fields" begin
    j = readjson("""{"id": 1}""")
    @test_throws Exception BasisCommon.conv(j, SimpleConv)
end

@testset "conv type stability (JET)" begin
    if !_JET_AVAILABLE
        @info "JET not available; skipping type stability checks."
        @test true
    else
        function filter_reports(reports, allowed_substrings)
            if isempty(allowed_substrings)
                return reports
            end
            filtered = JET.InferenceErrorReport[]
            for report in reports
                rendered = sprint(JET.print_report, report)
                if !any(sub -> occursin(sub, rendered), allowed_substrings)
                    push!(filtered, report)
                end
            end
            return filtered
        end

        function jet_reports(::Type{T}) where {T}
            result = JET.report_opt(
                BasisCommon.conv,
                Tuple{JSON3.Object, Type{T}};
                target_modules=(BasisCommon,),
            )
            return JET.get_reports(result)
        end
        @test isempty(jet_reports(SimpleConv))
        @test isempty(jet_reports(WithOptional))
        @test isempty(jet_reports(WithNumbers))
        allowed_datetime_dispatch = ("runtime dispatch detected: BasisCommon.DateTime",)
        @test isempty(filter_reports(jet_reports(UserProfile), allowed_datetime_dispatch))
        @test isempty(filter_reports(jet_reports(Team), allowed_datetime_dispatch))
        @test isempty(jet_reports(WithDict))

        result_vec = JET.report_opt(
            BasisCommon.conv,
            Tuple{JSON3.Array, Type{Vector{SimpleConv}}};
            target_modules=(BasisCommon,),
        )
        allowed_array_dispatch = (
            "runtime dispatch detected: (j::JSON3.Array)",
            "runtime dispatch detected: conv(%",
        )
        @test isempty(filter_reports(JET.get_reports(result_vec), allowed_array_dispatch))

        result_union = JET.report_opt(
            BasisCommon.conv,
            Tuple{JSON3.Object, Type{Union{Nothing, UserProfile}}};
            target_modules=(BasisCommon,),
        )
        allowed_union_dispatch = (
            "runtime dispatch detected: BasisCommon.DateTime",
            "runtime dispatch detected: conv(j::JSON3.Object, ::UserProfile)",
        )
        @test isempty(filter_reports(JET.get_reports(result_union), allowed_union_dispatch))
    end
end
