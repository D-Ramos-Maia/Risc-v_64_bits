// next_pc.sv
module next_pc (
    input  logic [63:0] pc,
    input  logic [63:0] branch_target,  // PC + imm, ou resultado do JALR
    input  logic        take_branch,    // branch tomado ou jump
    output logic [63:0] pc_plus4,
    output logic [63:0] pc_next
);

    assign pc_plus4 = pc + 64'd4;
    assign pc_next  = take_branch ? branch_target : pc_plus4;

endmodule