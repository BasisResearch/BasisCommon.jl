using Test
using BasisCommon.Session

function test_complex_process_code()
    state = Session.SessionState(Dict(), Dict())

    # Step 1: Initial evaluations
    mod1 = Module(:SessionModule1)
    code1 = """
    function add(a, b)
        a + b
    end
    """
    result, state = Session.process_code_with_module(code1, state, mod1)
    @test Session.retrieve_variable(state, :add) == nothing
    @test haskey(state.definitions, :add)

    mod2 = Module(:SessionModule2)
    code2 = """
    x = add(2, 3)
    """
    result, state = Session.process_code_with_module(code2, state, mod2)
    @test Session.retrieve_variable(state, :x) == 5

    mod3 = Module(:SessionModule3)
    code3 = """
    y = x * 2
    """
    result, state = Session.process_code_with_module(code3, state, mod3)
    @test Session.retrieve_variable(state, :y) == 10

    # Step 2: Save the session state to a file
    filename = joinpath(tempdir(), "session_state.dat")
    Session.save_state(state, filename)
    
    # Step 3: Load the session state from the file
    loaded_state = Session.load_state(filename)
    @test Session.retrieve_variable(loaded_state, :x) == 5
    @test Session.retrieve_variable(loaded_state, :y) == 10
    @test haskey(loaded_state.definitions, :add)
    
    # Step 4: Continue with more evaluations
    mod4 = Module(:SessionModule4)
    code4 = """
    z = y + add(5, 10)
    """
    result, loaded_state = Session.process_code_with_module(code4, loaded_state, mod4)
    @test Session.retrieve_variable(loaded_state, :z) == 10 + 15

    # Clean up the test file
    rm(filename)
end

function test_session_state()
    state = Session.SessionState(Dict(), Dict())
    @test state.variables == Dict()
    @test state.definitions == Dict()
end

function test_parsing_and_transformation()
    code = "x = 1 + 1"
    parsed_expr = Session.parse_code(code)
    @test isa(parsed_expr, Expr)
    @test parsed_expr.head == :(=)

    block_code = Session.transform_to_block(code)
    @test startswith(block_code, "begin")
    @test endswith(block_code, "end")
end

function test_evaluate_in_module()
    mod = Module(:TestModule)
    expr = Session.parse_code("x = 1 + 1")
    
    result = Core.eval(mod, expr)
    
    @test result == 2
    @test Core.eval(mod, :x) == 2
end

function test_store_and_retrieve_variable()
    state = Session.SessionState(Dict(), Dict())
    Session.store_variable!(state, :x, 42)
    
    @test state.variables[:x] == 42
    @test Session.retrieve_variable(state, :x) == 42
end

function test_define_new_definition!()
    state = Session.SessionState(Dict(), Dict())
    expr = Session.parse_code("function add(a, b) a + b end")
    
    Session.define_new_definition!(state, :add, expr)
    
    @test state.definitions[:add] == expr
end

function test_apply_session_state()
    mod = Module(:TestModule)
    state = Session.SessionState(Dict(:x => 42), Dict())
    expr = Session.parse_code("function add(a, b) a + b end")
    Session.define_new_definition!(state, :add, expr)
    
    Session.apply_session_state(mod, state)
    
    @test Core.eval(mod, :x) == 42
    @test isdefined(mod, :add)
end

function test_result_to_string()
    result = 42
    result_str = Session.result_to_string(result)
    
    @test result_str == "42"
end

function test_process_code()
    state = Session.SessionState(Dict(), Dict())
    code = """
    function add(a, b)
        a + b
    end
    x = add(2, 3)
    """
    
    result, updated_state = Session.process_code!(code, state)
    
    @test result == 5
    @test Session.retrieve_variable(updated_state, :x) == 5
    @test haskey(updated_state.definitions, :add)
end

# Run all tests
@testset "Session Tests" begin
    test_session_state()
    test_parsing_and_transformation()
    test_evaluate_in_module()
    test_store_and_retrieve_variable()
    test_define_new_definition!()
    test_apply_session_state()
    test_result_to_string()
    test_process_code()
    # test_complex_process_code()
end
