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
*/
package Tilelink_lite_Types;

`include "defined_parameters.bsv"
import GetPut ::*;
import FIFO ::*;
import SpecialFIFOs ::*;
import Connectable ::*;

//`ifdef TILEUH
//`define LANE_WIDTH 8
//`define XLEN 8

Integer v_lane_width = valueOf(`LANE_WIDTH);

typedef enum {	
  Get_data, 
	GetWrap, 
	PutPartialData, 
	PutFullData
} Opcode_lite deriving(Bits, Eq, FShow);			
			
typedef enum {	
  AccessAck, 
	AccessAckData
} D_Opcode_lite deriving(Bits, Eq, FShow);			

typedef Bit#(4) Data_size; //In bytes
typedef Bit#(2) M_source;
typedef Bit#(5) S_sink;
typedef Bit#(`PADDR) Address_width;
typedef Bit#(`LANE_WIDTH) Mask;
typedef Bit#(TMul#(8,`LANE_WIDTH)) Data;

// The A-channel is responsible for the master requests. The channel is A is split in control 
// section(c) data section(d) where the read masters only use control section and write masters 
// use both. For the slave side where it receives the request has the channel A intact.
typedef struct { 
		Opcode_lite    a_opcode;  // The opcode specifies if write or read requests
		Data_size			 a_size;    // The transfer size in 2^a_size bytes. if this is >3 then its a burst
		M_source 		   a_source;  // Master ID
		Address_width	 a_address; // Address for the request
} A_channel_control_lite deriving(Bits, Eq, FShow);
		
typedef struct { 
		Mask  a_mask;      // 8x(bytes in data lane) 1 bit mask for each byte 
		Data  a_data;			// data for the request	
} A_channel_data deriving(Bits, Eq, FShow);

typedef struct { 
		Opcode_lite a_opcode;
		Data_size		a_size;
		M_source a_source;
		Address_width	a_address;
		Mask  a_mask;
		Data	a_data;	
} A_channel_lite deriving(Bits, Eq, FShow);

// The channel D is responsible for the slave responses. It has the master ids and slave ids 
// carried through the channel
typedef struct { 
		D_Opcode_lite 	d_opcode;   //Opcode encodings for response with data or just ack
		Data_size				d_size;
		M_source 				d_source;
		S_sink					d_sink;
		Data					  d_data;	
		Bool					  d_error;
} D_channel_lite deriving(Bits, Eq, FShow);

interface Ifc_core_side_master_link_lite;

	//Towards the master
	interface Put#(A_channel_lite) master_request;
	interface Get#(D_channel_lite) master_response;

endinterface

interface Ifc_fabric_side_master_link_lite;
	//Towards the fabric
	interface Get#(A_channel_lite) fabric_request;
	interface Put#(D_channel_lite) fabric_response;
endinterface

//--------------------------------------Master Xactor--------------------------------------//
/* This is a xactor interface which connects core and master side of the fabric*/
interface Ifc_Master_link_lite;
  interface Ifc_core_side_master_link_lite core_side;
  interface Ifc_fabric_side_master_link_lite fabric_side;
endinterface

/* Master transactor - should be instantiated in the core side and the fabric side interface of
of the xactor should be exposed out of the core*/
module mkMasterXactorLite#(Bool xactor_guarded, Bool fabric_guarded)(Ifc_Master_link_lite);

// Created a pipelined version that will have a critical path all along the bus. If we want to break 
// the path we can 
// make the bus stall-less 
`ifdef TILELINK_LIGHT
  //data split of A-channel
	FIFOF#(A_channel_lite) ff_xactor_request <- mkGLFIFOF(xactor_guarded, fabric_guarded);   
  //response channel D-channel exposed out
	FIFOF#(D_channel_lite) ff_xactor_response <- mkGLFIFOF(xactor_guarded, fabric_guarded); 
`else
	FIFO#(A_channel_lite) ff_xactor_request <- mkSizedFIFO(2);
	FIFO#(D_channel_lite) ff_xactor_response <- mkSizedFIFO(2);
`endif

	interface core_side = interface Ifc_core_side_master_link_lite
		interface master_request = toPut(ff_xactor_request);
		interface master_response = toGet(ff_xactor_response);
	endinterface;

	interface fabric_side = interface Ifc_fabric_side_master_link_lite 
		interface fabric_request = toGet(ff_xactor_request);
		interface fabric_response = toPut(ff_xactor_response);
	endinterface;
	
endmodule

//----------------------------------------------------------------------------------------------//


//---------------------------------Slave Xactor------------------------------------------------//

interface Ifc_core_side_slave_link_lite;
	interface Get#(A_channel_lite) xactor_request;
	interface Put#(D_channel_lite) xactor_response;
endinterface

interface Ifc_fabric_side_slave_link_lite;
	interface Put#(A_channel_lite) fabric_request;
	interface Get#(D_channel_lite) fabric_response;
endinterface

interface Ifc_Slave_link_lite;
	interface Ifc_core_side_slave_link_lite core_side;
	interface Ifc_fabric_side_slave_link_lite fabric_side;
endinterface

module mkSlaveXactorLite#(Bool xactor_guarded, Bool fabric_guarded)(Ifc_Slave_link_lite);

`ifdef TILELINK_LIGHT
	FIFOF#(A_channel_lite) ff_xactor_request <- mkGLFIFOF(xactor_guarded, fabric_guarded);
	FIFOF#(D_channel_lite) ff_xactor_response <- mkGLFIFOF(xactor_guarded, fabric_guarded);
`else
	FIFO#(A_channel_lite) ff_xactor_request <- mkSizedFIFO(2);
	FIFO#(D_channel_lite) ff_xactor_response <- mkSizedFIFO(2);
`endif

	//rule rl_xactor_to_fabric(!isValid(rg_d_channel));
	//	let lv_response = ff_xactor_response.first;
	//	rg_d_channel <= tagged Valid lv_response;
	//	ff_xactor_response.deq;
	//endrule

	//rule rl_fabric_to_xactor(rg_a_channel matches tagged Valid .req);
	//	let lv_req = req;
	//	ff_xactor_request.enq(req);
	//	rg_a_channel <= tagged Invalid
	//endrule

interface core_side = interface Ifc_core_side_slave_link_lite;
	interface xactor_request = toGet(ff_xactor_request);
	interface xactor_response = toPut(ff_xactor_response);
endinterface;

interface fabric_side = interface Ifc_fabric_side_slave_link_lite;
	interface fabric_request = toPut(ff_xactor_request);
	interface fabric_response = toGet(ff_xactor_response);
endinterface;

endmodule

//------------------------------------------- Master Fabric -------------------------------------//

interface Ifc_Master_fabric_side_a_channel_lite;
	(* always_ready *)
	method A_channel_lite fabric_a_channel;
	(* always_ready *)
	method Bool fabric_a_channel_valid;
	(* always_ready, always_enabled *)
	method Action fabric_a_channel_ready(Bool req_ready);
endinterface

interface Ifc_Master_fabric_side_d_channel_lite;
	(* always_ready, always_enabled *)
	method Action fabric_d_channel(D_channel_lite resp);
	(* always_ready *)
	method Bool fabric_d_channel_ready;
endinterface

	//Communication with the xactor
interface Ifc_master_tilelink_core_side_lite;
	interface Put#(A_channel_lite) xactor_request;
	interface Get#(D_channel_lite) xactor_response;
endinterface

interface Ifc_Master_tilelink_lite;
	interface Ifc_master_tilelink_core_side_lite v_from_masters;
	//communication with the fabric
	interface Ifc_Master_fabric_side_d_channel_lite fabric_side_response;
	interface Ifc_Master_fabric_side_a_channel_lite fabric_side_request;
endinterface

module mkMasterFabricLite(Ifc_Master_tilelink_lite);

  Reg#(Maybe#(A_channel_lite)) rg_a_channel[2] <- mkCReg(2, tagged Invalid);
  Reg#(Maybe#(D_channel_lite)) rg_d_channel[2] <- mkCReg(2, tagged Invalid);

	interface v_from_masters = interface Ifc_master_tilelink_core_side_lite
	  interface xactor_request = interface Put
		  method Action put(A_channel_lite req_data);
			  rg_a_channel[0] <= tagged Valid req_data;
				`ifdef verbose 
          $display($time, "\tTILELINK : Request from Xactor data signals", fshow(req_data)); 
        `endif
			endmethod
		endinterface;
												
		interface xactor_response = interface Get;
		  method ActionValue#(D_channel_lite) get if(isValid(rg_d_channel[1]));
			  let resp = validValue(rg_d_channel[1]);
				rg_d_channel[1] <= tagged Invalid;
				`ifdef verbose 
          $display($time, "\tTILELINK : Response to Xactor data signals", fshow(resp)); 
        `endif
				return resp;
			endmethod
		endinterface;
	endinterface;
												
	interface fabric_side_response = interface Ifc_Master_fabric_side_d_channel_lite
	  method Action fabric_d_channel(D_channel_lite resp);
		  rg_d_channel[0] <= tagged Valid resp; 
		endmethod
		method Bool fabric_d_channel_ready;
		  return !isValid(rg_d_channel[0]);
		endmethod
	endinterface;

	//while sending it to the fabric the control section and the data section should be merged
	interface fabric_side_request = interface Ifc_Master_fabric_side_a_channel_lite
	  method A_channel_lite fabric_a_channel;
			return validValue(rg_a_channel[1]);
		endmethod
		method Bool fabric_a_channel_valid;           //master valid signal to the fabric
			return isValid(rg_a_channel[1]);
		endmethod
		method Action fabric_a_channel_ready(Bool req_ready); //master ready signal to the fabric
			if(req_ready)
				rg_a_channel[1] <= tagged Invalid;
		endmethod
	endinterface;

endmodule


//------------------------------------------- Slave Fabric -------------------------------------//

interface Ifc_slave_tilelink_core_side_lite;
	//communication with the xactors
	interface Get#(A_channel_lite) xactor_request;
	interface Put#(D_channel_lite) xactor_response;
endinterface

interface Ifc_Slave_fabric_side_a_channel_lite;
	(* always_ready, always_enabled *)
	method Action fabric_a_channel(A_channel_lite req);
	(* always_ready *)
	method Bool fabric_a_channel_ready;
endinterface

interface Ifc_Slave_fabric_side_d_channel_lite;
	(* always_ready *)
	method D_channel_lite fabric_d_channel;
	(* always_ready *)
	method Bool fabric_d_channel_valid;
	(* always_ready, always_enabled *)
	method Action fabric_d_channel_ready(Bool req_ready);
endinterface

interface Ifc_Slave_tilelink_lite;
	interface Ifc_slave_tilelink_core_side_lite v_to_slaves;
	//communication with the fabric
	interface Ifc_Slave_fabric_side_d_channel_lite fabric_side_response;
	interface Ifc_Slave_fabric_side_a_channel_lite fabric_side_request;
endinterface

module mkSlaveFabricLite(Ifc_Slave_tilelink_lite);

  Reg#(Maybe#(A_channel_lite)) rg_a_channel[3] <- mkCReg(3, tagged Invalid);
  Reg#(Maybe#(D_channel_lite)) rg_d_channel[3] <- mkCReg(3, tagged Invalid);

	interface v_to_slaves = interface Ifc_slave_tilelink_core_side_lite ;
		interface xactor_request = interface Get
			method ActionValue#(A_channel_lite) get if(isValid(rg_a_channel[1]));
				let req = validValue(rg_a_channel[1]);
				rg_a_channel[1] <= tagged Invalid;
				`ifdef verbose 
          $display($time, "\tTILELINK : Slave side request to Xactor ", fshow(req)); 
        `endif
				return req;
			endmethod
		endinterface;

		interface xactor_response = interface Put
			method Action put(D_channel_lite resp) if(!isValid(rg_d_channel[0]));
				`ifdef verbose 
          $display($time, "\tTILELINK : Slave side response from Xactor ", fshow(resp)); 
        `endif
				rg_d_channel[0] <= tagged Valid resp;
			endmethod
		endinterface;
	endinterface;

	interface fabric_side_response = interface Ifc_Slave_fabric_side_d_channel_lite
	  method D_channel_lite fabric_d_channel;
  		return validValue(rg_d_channel[1]);
	  endmethod
  	method Bool fabric_d_channel_valid;
	  	return isValid(rg_d_channel[1]);
  	endmethod
		//if the beat has been exchanged the packet can be invalidated on the sending side	
		method Action fabric_d_channel_ready(Bool req_ready);
		  if(req_ready)
			  rg_d_channel[1] <= tagged Invalid;
		endmethod
	endinterface;

	interface fabric_side_request = interface Ifc_Slave_fabric_side_a_channel_lite
		//if the beat has been exchanged the packet can be invalidated on the sending side	
	  method Action fabric_a_channel(A_channel_lite req);
		  rg_a_channel[0] <= tagged Valid req;
		endmethod
		method Bool fabric_a_channel_ready; 
		  return !isValid(rg_a_channel[0]);
		endmethod
	endinterface;
endmodule

instance Connectable#(Ifc_fabric_side_master_link_lite, Ifc_master_tilelink_core_side_lite);
	
	module mkConnection#(Ifc_fabric_side_master_link_lite xactor, Ifc_master_tilelink_core_side_lite fabric)(Empty);
		
		rule rl_connect_control_request;
			let x <-  xactor.fabric_request.get;
			fabric.xactor_request.put(x); 
		endrule
		rule rl_connect_data_response;
			let x <- fabric.xactor_response.get; 
			xactor.fabric_response.put(x);
		endrule
	endmodule

endinstance

instance Connectable#( Ifc_slave_tilelink_core_side_lite, Ifc_fabric_side_slave_link_lite);
	
	module mkConnection#(Ifc_slave_tilelink_core_side_lite fabric, Ifc_fabric_side_slave_link_lite xactor)(Empty);
		
		rule rl_connect_request;
			let x <- fabric.xactor_request.get;
			xactor.fabric_request.put(x);
		endrule
		rule rl_connect_data_response;
			let x <- xactor.fabric_response.get;
			fabric.xactor_response.put(x);
		endrule
	endmodule

endinstance

endpackage
