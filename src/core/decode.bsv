/* 
Copyright (c) 2013, IIT Madras All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted
provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions
  and the following disclaimer.  
* Redistributions in binary form must reproduce the above copyright notice, this list of 
  conditions and the following disclaimer in the documentation and/or other materials provided 
 with the distribution.  
* Neither the name of IIT Madras  nor the names of its contributors may be used to endorse or 
  promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------------------------

Author: Neel Gala, Aditya Mathur
Email id: neelgala@gmail.com
Details:

--------------------------------------------------------------------------------------------------
*/
package decode;
  
  // pacakge imports from project
  import common_types::*;
  `include "common_params.bsv"

  (*noinline*)
    function PIPE1_DS decoder_func(Bit#(32) inst,Bit#(PADDR) shadow_pc, Bit#(1) epoch);
			Bit#(5) rs1=inst[19:15];
			Bit#(5) rs2=inst[24:20];
			Bit#(5) rd =inst[11:7] ;
			Bit#(5) opcode= inst[6:2];
			Bit#(3) funct3= inst[14:12];
			Bool word32 =False;
			Bit#(PADDR) pc=shadow_pc;

			//operand types
			Operand1_type rs1type=IntegerRF;
			Operand2_type rs2type=IntegerRF;

			//memory access type
			Access_type mem_access=Load;
			if(opcode[3]=='b1 && opcode[1]==0)
				mem_access=Store;

			//immediate value 
			Bit#(XLEN) immediate_value=signExtend(inst[31:20]);
			if(opcode==`JAL_R_op)
				immediate_value=signExtend({inst[31:20],1'b0});
			else if(opcode==`BRANCH_op)
				immediate_value=signExtend({inst[31],inst[7],inst[30:25],inst[11:8],1'b0}); 
			else if	(opcode==`STORE_op)
				immediate_value=signExtend({inst[31:25],inst[11:7]});
			else if(opcode==`SYSTEM_INSTR_op)//what should be done for systems instruction		
				immediate_value[16:12]=inst[19:15];

			//instruction following U OR UJ TYPE INSTRUCTION FORMAT	
			//funct3[2]==1 might not be required as division is not included till now
			if (opcode==`JAL_R_op || (opcode==`SYSTEM_INSTR_op && funct3[2]==1))	
				rs1=0;
			//instruction following I,U OR UJ INSTRUCTION FORMAT	
			if (opcode==`SYSTEM_INSTR_op || opcode[4:2]=='b000// CSR or ( (F)Load or FENCE ) 
  				||opcode[4:2]=='b001 || opcode==`JAL_R_op)	//LUI or JAL 
				rs2=0;
			//insturction following S OR SB TYPE INSTRUCTION FORMAT
			if (opcode==`BRANCH_op || opcode[4:1]=='b0100)	
				rd=0;

			if(opcode==`JAL_R_op)	
				rs1type=PC;
			if(opcode==`JAL_R_op || opcode=='b001)	
				rs2type=Immediate;
			
			//instructions which support word lenght operation in RV64 are to be added in Alu
			//need to be edited according to the supported instruction

			//if(opcode==`IMM_ARITHW_op || opcode==`MULDIVW_op ||
			 //opcode==`ARITHW_op ||(opcode[4:3]=='b10 && funct7[0]==0)||
			  //(opcode[4:1]=='b0101 && funct3[0]==0)) 
      		//word32=True;
      			

      		Instruction_type inst_type=NOP;
      		if(opcode[4:3]=='b11)begin
      			case(opcode[2:0])
      				'b001:inst_type=JAL_R;
      				'b000:inst_type=BRANCH;
      				'b100:inst_type=SYSTEM_INSTR;
      			endcase
      		end
      		else if(opcode[4:3]=='b00)begin
      			case(opcode[2:0])
      				'b000,'b001:inst_type=MEMORY;
      				'b101,'b100,'b110:inst_type=ALU;
      			endcase
      		end
      		Bit#(4) fn=0;
      		if(opcode==`BRANCH_op)begin
      			if(funct3[2]==0)
      				fn={2'b0,1,funct3[0]};
      			else
      				fn={1'b1,funct3}	;
      		end
      		else if(opcode==`JAL_R_op || opcode==`LOAD_op || opcode==`STORE_op)
      			fn=0;
      		else if(opcode==`IMM_ARITH_op)begin
			fn=case(funct3)
				'b010: 'b1100;
				'b011: 'b1110;
				'b101: 'b0101;
				default:{1'b0,funct3};
			endcase;
			end
			else if(opcode==`ARITH_op)begin
				fn=case(funct3)
					'b000:'b0000;
					'b010:'b1100;
					'b011:'b1110;
					'b101:'b0101;
					default:{1'b0,funct3};
			endcase;
			end		
      		else if(opcode[4:3]=='b10)	
      			fn=opcode[3:0];
		

            Tuple6#(Operand1_type,Operand2_type,Instruction_type,Access_type,Bit#(PADDR), Bit#(1)) 
                                type_tuple = tuple6(rs1type,rs2type,inst_type,mem_access,pc,epoch);

            return tuple8(fn, rs1, rs2, rd, immediate_value, word32, funct3, type_tuple);            
    endfunction
endpackage
