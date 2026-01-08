using Test
using BasisCommon
using BasisCommon.Session
using BasisCommon.ExoVars

@testset "Session Tests" begin
    @testset "process_code returns 4 for '2+2'" begin
        code = "2 + 2"
        state = Session.empty_sessionstate()
        result, new_state = Session.process_code(code, state)
        @test result == 4
        @test new_state === state  # In this case, the session state should be unchanged
    end
end

@testset "ExoVars Tests" begin
    @testset "with_env_handler retrieves ENV value" begin
        ENV["MY_TEST_VAR"] = "Hello from ENV"
        val = ExoVars.with_env_handler() do
            ExoVars.get_exo_value("MY_TEST_VAR")
        end
        @test val == "Hello from ENV"
    end
end

include("conv.jl")
