// branch_unit.sv
module branch_unit
    import rv_pkg::*;
(
    input  logic        is_branch,
    input  branch_e     branch_type,
    input  logic [63:0] rs1_data,
    input  logic [63:0] rs2_data,
    output logic        taken
);

    logic signed [63:0] a_s, b_s;
    assign a_s = rs1_data;
    assign b_s = rs2_data;

    logic cond;

    always_comb begin
        unique case (branch_type)
            BR_EQ:   cond = (rs1_data == rs2_data);
            BR_NE:   cond = (rs1_data != rs2_data);
            BR_LT:   cond = (a_s < b_s);
            BR_GE:   cond = (a_s >= b_s);
            BR_LTU:  cond = (rs1_data <  rs2_data);
            BR_GEU:  cond = (rs1_data >= rs2_data);
            default: cond = 1'b0;
        endcase
    end

    assign taken = is_branch & cond;

endmodule