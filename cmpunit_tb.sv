`timescale 1ns / 1ps

module tb_cmpunit;

    // Parameters
    parameter CLK_PERIOD = 10; // 10ns clock period (100MHz)
    
    // Testbench signals
    logic clk;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    cmp_op_t cmp_op;
    logic result;
    logic expected_result;
    
    // Test statistics
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // Import types package (assuming it contains cmp_op_t definition)
    import types::*;
    
    // Instantiate the Unit Under Test (UUT)
    cmpunit uut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .cmp_op(cmp_op),
        .result(result)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test procedure
    initial begin
        $display("========================================");
        $display("Starting RISC-V Comparison Unit Testbench");
        $display("========================================");
        
        // Initialize signals
        operand_a = 0;
        operand_b = 0;
        cmp_op = CMP_EQ;
        
        // Wait for a few clock cycles
        repeat(3) @(posedge clk);
        
        // Test all comparison operations with various test cases
        test_equal_operations();
        test_not_equal_operations();
        test_signed_less_than();
        test_signed_greater_equal();
        test_unsigned_less_than();
        test_unsigned_greater_equal();
        test_edge_cases();
        test_random_cases();
        
        // Final results
        $display("\n========================================");
        $display("Test Summary:");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("Success Rate: %0.1f%%", (real'(pass_count)/real'(test_count))*100.0);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("✅ ALL TESTS PASSED!");
        end else begin
            $display("❌ SOME TESTS FAILED!");
        end
        
        $finish;
    end
    
    // Test CMP_EQ (Equal) operations
    task test_equal_operations();
        $display("\n--- Testing CMP_EQ Operations ---");
        
        // Equal values
        check_comparison(32'h12345678, 32'h12345678, CMP_EQ, 1'b1, "Equal values");
        check_comparison(32'h00000000, 32'h00000000, CMP_EQ, 1'b1, "Zero values");
        check_comparison(32'hFFFFFFFF, 32'hFFFFFFFF, CMP_EQ, 1'b1, "All ones");
        
        // Unequal values
        check_comparison(32'h12345678, 32'h12345679, CMP_EQ, 1'b0, "Different by 1");
        check_comparison(32'h00000000, 32'h00000001, CMP_EQ, 1'b0, "Zero vs one");
        check_comparison(32'hFFFFFFFF, 32'h7FFFFFFF, CMP_EQ, 1'b0, "Max vs positive max");
    endtask
    
    // Test CMP_NE (Not Equal) operations
    task test_not_equal_operations();
        $display("\n--- Testing CMP_NE Operations ---");
        
        // Unequal values
        check_comparison(32'h12345678, 32'h12345679, CMP_NE, 1'b1, "Different by 1");
        check_comparison(32'h00000000, 32'h00000001, CMP_NE, 1'b1, "Zero vs one");
        check_comparison(32'hFFFFFFFF, 32'h7FFFFFFF, CMP_NE, 1'b1, "Max vs positive max");
        
        // Equal values
        check_comparison(32'h12345678, 32'h12345678, CMP_NE, 1'b0, "Equal values");
        check_comparison(32'h00000000, 32'h00000000, CMP_NE, 1'b0, "Zero values");
        check_comparison(32'hFFFFFFFF, 32'hFFFFFFFF, CMP_NE, 1'b0, "All ones");
    endtask
    
    // Test CMP_LT (Signed Less Than) operations
    task test_signed_less_than();
        $display("\n--- Testing CMP_LT (Signed Less Than) Operations ---");
        
        // Positive numbers
        check_comparison(32'h00000001, 32'h00000002, CMP_LT, 1'b1, "1 < 2 (positive)");
        check_comparison(32'h00000002, 32'h00000001, CMP_LT, 1'b0, "2 < 1 (positive)");
        
        // Negative numbers
        check_comparison(32'hFFFFFFFE, 32'hFFFFFFFF, CMP_LT, 1'b1, "-2 < -1");
        check_comparison(32'hFFFFFFFF, 32'hFFFFFFFE, CMP_LT, 1'b0, "-1 < -2");
        
        // Mixed positive/negative
        check_comparison(32'hFFFFFFFF, 32'h00000001, CMP_LT, 1'b1, "-1 < 1");
        check_comparison(32'h00000001, 32'hFFFFFFFF, CMP_LT, 1'b0, "1 < -1");
        
        // Zero cases
        check_comparison(32'h00000000, 32'h00000001, CMP_LT, 1'b1, "0 < 1");
        check_comparison(32'hFFFFFFFF, 32'h00000000, CMP_LT, 1'b1, "-1 < 0");
        check_comparison(32'h00000000, 32'h00000000, CMP_LT, 1'b0, "0 < 0");
    endtask
    
    // Test CMP_GE (Signed Greater or Equal) operations
    task test_signed_greater_equal();
        $display("\n--- Testing CMP_GE (Signed Greater or Equal) Operations ---");
        
        // Greater cases
        check_comparison(32'h00000002, 32'h00000001, CMP_GE, 1'b1, "2 >= 1");
        check_comparison(32'hFFFFFFFF, 32'hFFFFFFFE, CMP_GE, 1'b1, "-1 >= -2");
        check_comparison(32'h00000001, 32'hFFFFFFFF, CMP_GE, 1'b1, "1 >= -1");
        
        // Equal cases
        check_comparison(32'h12345678, 32'h12345678, CMP_GE, 1'b1, "Equal values");
        check_comparison(32'h00000000, 32'h00000000, CMP_GE, 1'b1, "Zero equal");
        
        // Less than cases
        check_comparison(32'h00000001, 32'h00000002, CMP_GE, 1'b0, "1 >= 2");
        check_comparison(32'hFFFFFFFF, 32'h00000001, CMP_GE, 1'b0, "-1 >= 1");
    endtask
    
    // Test CMP_LTU (Unsigned Less Than) operations
    task test_unsigned_less_than();
        $display("\n--- Testing CMP_LTU (Unsigned Less Than) Operations ---");
        
        // Basic unsigned comparisons
        check_comparison(32'h00000001, 32'h00000002, CMP_LTU, 1'b1, "1 < 2 (unsigned)");
        check_comparison(32'h00000002, 32'h00000001, CMP_LTU, 1'b0, "2 < 1 (unsigned)");
        
        // Large numbers (would be negative in signed)
        check_comparison(32'h7FFFFFFF, 32'h80000000, CMP_LTU, 1'b1, "0x7FFFFFFF < 0x80000000 (unsigned)");
        check_comparison(32'h80000000, 32'hFFFFFFFF, CMP_LTU, 1'b1, "0x80000000 < 0xFFFFFFFF (unsigned)");
        check_comparison(32'hFFFFFFFF, 32'h00000001, CMP_LTU, 1'b0, "0xFFFFFFFF < 1 (unsigned)");
        
        // Zero cases
        check_comparison(32'h00000000, 32'h00000001, CMP_LTU, 1'b1, "0 < 1 (unsigned)");
        check_comparison(32'h00000000, 32'h00000000, CMP_LTU, 1'b0, "0 < 0 (unsigned)");
    endtask
    
    // Test CMP_GEU (Unsigned Greater or Equal) operations
    task test_unsigned_greater_equal();
        $display("\n--- Testing CMP_GEU (Unsigned Greater or Equal) Operations ---");
        
        // Greater cases
        check_comparison(32'h00000002, 32'h00000001, CMP_GEU, 1'b1, "2 >= 1 (unsigned)");
        check_comparison(32'h80000000, 32'h7FFFFFFF, CMP_GEU, 1'b1, "0x80000000 >= 0x7FFFFFFF (unsigned)");
        check_comparison(32'hFFFFFFFF, 32'h00000001, CMP_GEU, 1'b1, "0xFFFFFFFF >= 1 (unsigned)");
        
        // Equal cases
        check_comparison(32'h12345678, 32'h12345678, CMP_GEU, 1'b1, "Equal values (unsigned)");
        check_comparison(32'hFFFFFFFF, 32'hFFFFFFFF, CMP_GEU, 1'b1, "Max values equal (unsigned)");
        
        // Less than cases
        check_comparison(32'h00000001, 32'h00000002, CMP_GEU, 1'b0, "1 >= 2 (unsigned)");
        check_comparison(32'h7FFFFFFF, 32'h80000000, CMP_GEU, 1'b0, "0x7FFFFFFF >= 0x80000000 (unsigned)");
    endtask
    
    // Test edge cases
    task test_edge_cases();
        $display("\n--- Testing Edge Cases ---");
        
        // Maximum and minimum values
        check_comparison(32'h7FFFFFFF, 32'h80000000, CMP_LT, 1'b0, "Max positive < Min negative (signed)");
        check_comparison(32'h80000000, 32'h7FFFFFFF, CMP_LT, 1'b1, "Min negative < Max positive (signed)");
        
        // Boundary values for unsigned
        check_comparison(32'hFFFFFFFF, 32'h00000000, CMP_LTU, 1'b0, "Max < Min (unsigned)");
        check_comparison(32'h00000000, 32'hFFFFFFFF, CMP_LTU, 1'b1, "Min < Max (unsigned)");
        
        // Powers of 2
        check_comparison(32'h00000001, 32'h00000002, CMP_LT, 1'b1, "1 < 2");
        check_comparison(32'h00000002, 32'h00000004, CMP_LT, 1'b1, "2 < 4");
        check_comparison(32'h40000000, 32'h80000000, CMP_LTU, 1'b1, "0x40000000 < 0x80000000 (unsigned)");
    endtask
    
    // Test with random values
    task test_random_cases();
        $display("\n--- Testing Random Cases ---");
        
        for (int i = 0; i < 20; i++) begin
            automatic logic [31:0] rand_a = $random();
            automatic logic [31:0] rand_b = $random();
            automatic cmp_op_t rand_op = cmp_op_t'($urandom_range(0, 5));
            
            // Calculate expected result
            case (rand_op)
                CMP_EQ:  expected_result = (rand_a == rand_b);
                CMP_NE:  expected_result = (rand_a != rand_b);
                CMP_LT:  expected_result = ($signed(rand_a) < $signed(rand_b));
                CMP_GE:  expected_result = ($signed(rand_a) >= $signed(rand_b));
                CMP_LTU: expected_result = (rand_a < rand_b);
                CMP_GEU: expected_result = (rand_a >= rand_b);
                default: expected_result = 1'b0;
            endcase
            
            check_comparison(rand_a, rand_b, rand_op, expected_result, $sformatf("Random test %0d", i+1));
        end
    endtask
    
    // Helper task to check a single comparison
    task check_comparison(
        input logic [31:0] a,
        input logic [31:0] b, 
        input cmp_op_t op,
        input logic expected,
        input string description
    );
        operand_a = a;
        operand_b = b;
        cmp_op = op;
        
        // Wait for combinational logic to settle
        #1;
        
        test_count++;
        
        if (result === expected) begin
            pass_count++;
            $display("✅ PASS: %s | A=0x%08h, B=0x%08h, Op=%s, Result=%b", 
                    description, a, b, op.name(), result);
        end else begin
            fail_count++;
            $display("❌ FAIL: %s | A=0x%08h, B=0x%08h, Op=%s, Expected=%b, Got=%b", 
                    description, a, b, op.name(), expected, result);
        end
        
        // Wait a clock cycle before next test
        @(posedge clk);
    endtask

endmodule
