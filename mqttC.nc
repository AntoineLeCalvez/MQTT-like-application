/**
 *  IOT - Project
 *  Source file for implementation of module sendAckC in which
 *  we try to stick as much as possible to the MQTT model
 *
 *  @author Antoine Le Calvez - Mëmëdhe G. Ibrahimi
 */

#include "mqtt.h"
#include "Timer.h"

module mqttC {

  uses {
	interface Boot;
    	interface AMPacket;
	interface Packet;
	interface PacketAcknowledgements;
    	interface AMSend;
    	interface SplitControl;
    	interface Receive;
	interface Read<uint16_t>;
	interface Timer<TMilli> as Timer0;
	interface Timer<TMilli> as Timer1;
	interface Timer<TMilli> as Timer2;
	interface Timer<TMilli> as Timer3;
	interface Timer<TMilli> as Timer4;
  }

} implementation {
  
  //Declaration of the different variables used
  uint8_t nbNodesConnected=0; 
  uint8_t messageID = 1;
  uint8_t retransmission = 0;
  uint16_t valueRetrans = -1;
  uint16_t valueToForward = -1;
  uint8_t topicToForward = -1;
  uint8_t sourceToForward = -1;
  uint8_t index = 0;
  uint8_t forwardRetrans = 0;
  uint8_t forwarding = 0;
  message_t packet;

  //Declaration of the different tasks
  task void initialize();
  task void sendConnect();
  task void sendSubscribe();
  task void sendPublish();
  task void sendForward();
  
  //***************** Task initialize ********************//
  //This task is aimed at initializing the different
  //arrays when the MQTT broker is turned on
  task void initialize() {
   int i, j;
   for(i=0; i<MAX_NB_NODES; i++)
   {
	nodesToForward[i]=-1;
	connectedNodes[i]=0;
	publishedMsgID[i]=-1;
	for(j=0;j<3;j++)
	{
		subscriptions[i][j]=-1;
	}
    }
  }
  
  //***************** Task sendConnect ********************//
  // This task is used by nodes to send a connect request to the MQTT 
  // broker which is supposed to answer by a CONNACK
  task void sendConnect() {
	my_msg_connect_t* mess=(my_msg_connect_t*)(call Packet.getPayload(&packet,sizeof(my_msg_connect_t)));
	mess->type = CONNECT; //Fills the type field	    
	dbg("radio_send", "Try to send a connect request to node 1 (MQTT Broker) at time %s \n", sim_time_string());
	call PacketAcknowledgements.requestAck( &packet );//Asks for an ACK
	if(call AMSend.send(1,&packet,sizeof(my_msg_connect_t)) == SUCCESS){ //Tries to send the packet to the MQTT Broker
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );//Displays the payload length
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );//Displays the source
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );//Displays the destination
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );//Displays the AM Type
	  dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type); //Displays the type of msg
        }
   }

  //***************** Task sendSubscribe ********************//
  // This task is used by nodes to send a subscribe request to 
  // the MQTT broker which is supposed to answer by a SUBACK
  task void sendSubscribe() {
	my_msg_subscribe_t* mess=(my_msg_subscribe_t*)(call Packet.getPayload(&packet,sizeof(my_msg_subscribe_t)));
	mess->type = SUBSCRIBE; //Fills the type field	
	if(TOS_NODE_ID<5){ //From node 2 to 4, we define a high QOS on all topics, this choice is an arbitrary one
		mess->qos[TEMPERATURE-1] = QOS_HIGH;
		mess->qos[HUMIDITY-1] = QOS_HIGH;
		mess->qos[LUMINOSITY-1] = QOS_HIGH;
	} else { //From node 5 to 8, we define a low QOS on all topics, this choice is an arbitrary one
		mess->qos[TEMPERATURE-1] = QOS_LOW;
		mess->qos[HUMIDITY-1] = QOS_LOW;
		mess->qos[LUMINOSITY-1] = QOS_LOW;
	}
	if(TOS_NODE_ID%2 == 0){	//If the nodeID is even, we subscribe to all the topics, this choice is an arbitrary one
		mess->topic[TEMPERATURE-1] = 1;
		mess->topic[HUMIDITY-1] = 1;
		mess->topic[LUMINOSITY-1] = 1;
	} else { //If the nodeID is odd, we subscribe to TEMPERATURE and HUMIDITY only, this choice is an arbitrary one
		mess->topic[TEMPERATURE-1] = 1;
		mess->topic[HUMIDITY-1] = 1; 
		mess->topic[LUMINOSITY-1] = 0;
	}	   
	dbg("radio_send", "Try to send a subscribe request to node 1 (MQTT Broker) at time %s \n", sim_time_string());
	call PacketAcknowledgements.requestAck( &packet ); //Asks for an ACK
	if(call AMSend.send(1,&packet,sizeof(my_msg_subscribe_t)) == SUCCESS){ //Tries to send the packet to the MQTT Broker	
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) ); //Displays the payload length
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) ); //Displays the source
	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) ); //Displays the destination
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) ); //Displays the AM Type
	  dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type); //Displays the type of msg
	  dbg_clear("radio_pack", "\t\t Topic: [%hhu %hhu %hhu] \n", mess->topic[0], mess->topic[1], mess->topic[2]); //Displays the topics to subscribe to*/
	  dbg_clear("radio_pack", "\t\t QOS: [%d %d %d] \n", mess->qos[0], mess->qos[1], mess->qos[2]); /*Displays the different QOS for each topic*/
        }
   }      
  
  //***************** Task sendPublish ********************//
  //This task is used by the different nodes to sending a 
  //publish message to the MQTT broker
  task void sendPublish(){
	call Read.read(); //Reads the value of the FakeSensor and sends the publish message
  }

  //***************** Task sendForward ********************//
  //This task is used by the MQTT broker after receiving a
  //publish message from a node, the goal is to distribute
  //the information to all the nodes subscribed to the topic
  task void sendForward() {
	int l, found = 0;
	my_msg_forward_t* mess=(my_msg_forward_t*)(call Packet.getPayload(&packet,sizeof(my_msg_forward_t)));
	mess->type = FORWARD; 
	mess->value = valueToForward;
	mess->source = sourceToForward;
	mess->topic = topicToForward;
	for(l=index; l<MAX_NB_NODES && found==0; l++){
		if(sourceToForward != l+2){
			if(nodesToForward[l] == QOS_HIGH){
				mess->qos = subscriptions[l][topicToForward-1];
				found = 1;
				index = l;
				call PacketAcknowledgements.requestAck( &packet );
				if(call AMSend.send(l+2,&packet,sizeof(my_msg_forward_t)) == SUCCESS){
					dbg("radio_send", "The MQTT broker tries to forward the publish request to node %hhu at time %s \n", l+2, sim_time_string());
					dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) ); //Displays the payload length
					dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( &packet )); //Displays the source
					dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( &packet ) ); //Displays the destination
					dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( &packet ) ); //Displays the AM Type
					dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type); //Displays the type of msg
					dbg_clear("radio_pack", "\t\t Topic: %hhu \n", mess->topic); //Displays the topic concerned by the publication
					dbg_clear("radio_pack", "\t\t QOS: %d \n", mess->qos); //Displays the QOS
					dbg_clear("radio_pack", "\t\t Value: %hhu \n", mess->value); //Displays the value of the sensor
					dbg_clear("radio_pack", "\t\t Initial source: %hhu \n", mess->source); //Displays the initial source of the publish message
				}
			} else if(nodesToForward[l] == QOS_LOW){
					mess->qos = subscriptions[l][topicToForward-1];
					call PacketAcknowledgements.noAck( &packet );
					found = 1;
					index = l;
					if(call AMSend.send(l+2,&packet,sizeof(my_msg_forward_t)) == SUCCESS){
						dbg("radio_send", "The MQTT broker tries to forward the publish request to node %hhu at time %s \n", l+2, sim_time_string());
						dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) ); //Displays the payload length
						dbg_clear("radio_pack","\t Source: %hhu \n", call AMPacket.source( &packet )); //Displays the source
						dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( &packet ) ); //Displays the destination
						dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( &packet ) ); //Displays the AM Type
						dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type); //Displays the type of msg
						dbg_clear("radio_pack", "\t\t Topic: %hhu \n", mess->topic); //Displays the topic concerned by the publication
						dbg_clear("radio_pack", "\t\t QOS: %hhu \n", mess->qos); //Displays the QOS
						dbg_clear("radio_pack", "\t\t Value: %hhu \n", mess->value); //Displays the value
						dbg_clear("radio_pack", "\t\t Initial source: %hhu \n", mess->source); //Displays the value
					}
		
			}
		}
		if(found == 0 && l == MAX_NB_NODES-1 && forwardRetrans == 0){
			forwarding=0;
			dbg_clear("radio_pack", "\t\t forwarding: %hhu \n", forwarding);
		}
		if (forwardRetrans==1 && l==MAX_NB_NODES-1){
			forwardRetrans=0;
			index=0;
			post sendForward();
		}	
	}	
  }


  //***************** Boot interface ********************//
  //This event is started at when a node boots, we turn on the
  //the radio and start sending CONNECT messages (except MQTT broker)
  event void Boot.booted() {
	dbg("boot","Application booted.\n");
	call SplitControl.start(); //Turn on the radio
	if ( TOS_NODE_ID > 1){
		call Timer0.startOneShot( 1000 ); //Use the Timer0 to send the CONNECT messages
	}	
  }

   //***************** Event Timer0 ********************//
   //Used to send CONNECT messages
   event void Timer0.fired() {
		post sendConnect();
  }

   //***************** Event Timer1 ********************//
   //Used to send SUBSCRIBE messages
   event void Timer1.fired() {
		post sendSubscribe();
   }
   
   //***************** Event Timer2 ********************//
   //Used to send PUBLISH messages
   event void Timer2.fired() {
	if (retransmission == 0){
		post sendPublish();
	}
   }

   //***************** Event Timer3 ********************//
   //Used to send PUBLISH messages
   event void Timer3.fired() {
		post sendPublish();
   }

   //***************** Event Timer4 ********************//
   //Used to send FORWARD messages
   event void Timer4.fired() {
		post sendForward();
   }
   

  //***************** SplitControl interface ********************//
  event void SplitControl.startDone(error_t err){
    if(err == SUCCESS) {
	dbg("radio","Radio on!\n");
	if ( TOS_NODE_ID == 1 ) { //If it is the MQTT Broker
	  dbg("role","I'm node 1: I'm the MQTT Broker\n");
	  post initialize();
	}
	if ( TOS_NODE_ID > 1 ) { //If it is a client node
	  dbg("role","I'm node %hhu: I'm a MQTT client node\n", TOS_NODE_ID);
	}
    }
    else{
	call SplitControl.start(); //If radio didn't turn on properly we start again
    }

  }
  
  event void SplitControl.stopDone(error_t err){}

  //********************* AMSend interface ****************//
  //Event used to make the nodes react after sending a packet and
  //permits to establish QOS policies
  event void AMSend.sendDone(message_t* buf,error_t err) {
    my_msg_connect_t* mess=(my_msg_connect_t*)(call Packet.getPayload(&packet,sizeof(my_msg_connect_t)));
    if(&packet == buf && err == SUCCESS ) { //If the message has been sent correctly
	dbg("radio_send", "Packet sent...");
	if (mess->type == CONNECT) { //If the packet sent was a CONNECT message
		if ( call PacketAcknowledgements.wasAcked( buf ) ) { //If the CONNACK has been received
		  dbg_clear("radio_ack", "and CONNACK received");
		  dbg_clear("radio_send", " at time %s \n", sim_time_string());		  
		  call Timer1.startOneShot( 1000 ); //Start the subscription procedure after 1 second
		} else { //If the CONNACK has not been received
		  dbg_clear("radio_ack", "but CONNACK was not received");
		  dbg_clear("radio_send", " at time %s \n", sim_time_string());
		  call Timer0.startOneShot( 1000 ); //Sends again a CONNECT message after 1 second
		}
        }
	if (mess->type == SUBSCRIBE) { //If the packet sent was a SUBSCRIBE message
		if ( call PacketAcknowledgements.wasAcked( buf ) ) { //If the SUBACK has been received
		  dbg_clear("radio_ack", "and SUBACK received");
		  dbg_clear("radio_send", " at time %s \n", sim_time_string());
		  call Timer2.startPeriodic( 20000 ); //Starts the publish procedure every 20 seconds
		} else { //If the SUBACK has not been received
		  dbg_clear("radio_ack", "but SUBACK was not received");
		  dbg_clear("radio_send", " at time %s \n", sim_time_string());
		  call Timer1.startOneShot( 1000 ); //Sends again a SUBSCRIBE message after 1 second
		}
        }
	if (mess->type == PUBLISH) { //If the message was a PUBLISH message
		my_msg_publish_t* messPublish=(my_msg_publish_t*)(call Packet.getPayload(&packet,sizeof(my_msg_publish_t)));
		if ( messPublish->qos == QOS_HIGH ){ //If QOS is high
			if (call PacketAcknowledgements.wasAcked( buf ) ) { //If the PUBACK has been received
				dbg_clear("radio_ack", "and PUBACK received");
			  	dbg_clear("radio_send", " at time %s \n", sim_time_string());
				messageID++;
				retransmission = 0;
			} else { //If the PUBACK has not been received
				dbg_clear("radio_ack", "but PUBACK was not received");
				dbg_clear("radio_send", " at time %s \n", sim_time_string());
				retransmission = 1;
				call Timer3.startOneShot( 10 ); //Sends again a PUBLISH message after 10 milliseconds
			}
		} else{ //If QOS is low
			messageID++;			
			dbg_clear("radio_ack", "The QoS was low so no acknowledgment required for this publication\n");
		}
        }
	if (mess->type == FORWARD) { //If the message was a FORWARD message
		if(nodesToForward[index]==QOS_HIGH){ //If QOS is high
			if(call PacketAcknowledgements.wasAcked( buf )){ //If FORWACK has been received
				nodesToForward[index]=-1;
				index++;
				dbg_clear("radio_ack", "and FORWACK received");
			  	dbg_clear("radio_send", " at time %s \n", sim_time_string());			
			} else{ //If FORWACK has not been received
				forwardRetrans=1;
				index++;
				dbg_clear("radio_ack", "but FORWACK was not received");
				dbg_clear("radio_send", " at time %s \n", sim_time_string());
			}
		}else{ //If QOS is low
			nodesToForward[index]=-1;
			dbg_clear("radio_ack", "and no acknowledgement required \n");		
		}
		post sendForward();	
	}
    }

  }

  //***************************** Receive interface *****************//
  //Event used when a node receives a packet
  event message_t* Receive.receive(message_t* buf,void* payload, uint8_t len) {
	int IDsource = call AMPacket.source( buf );	
	if(TOS_NODE_ID == 1) { //If the receiving node is the MQTT Broker
		my_msg_connect_t* mess=(my_msg_connect_t*)payload;
		if (mess->type == CONNECT){ //If the message is a CONNECT message
			dbg("radio_rec","Message received at time %s \n", sim_time_string());
			dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
			dbg_clear("radio_pack","\t Source: %hhu \n", IDsource );
			dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
			dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type);
			if(connectedNodes[IDsource-2] == 1){
				dbg_clear("radio_ack", "WARNING: the CONNACK has not been received the previous attempt by the node %hhu \n",IDsource );
			}else {	
				nbNodesConnected++;
			}
			connectedNodes[call AMPacket.source( buf )-2]=1; 
			dbg_clear("radio_ack", "Here are the connected nodes (seen from the MQTT broker)  : [%hhu, %hhu, %hhu, %hhu, %hhu, %hhu, %hhu, %hhu] \n", connectedNodes[0], connectedNodes[1], connectedNodes[2], connectedNodes[3], connectedNodes[4], connectedNodes[5], connectedNodes[6], connectedNodes[7]);
			dbg_clear("radio_ack", "Number of connected nodes: %hhu \n", nbNodesConnected);
		}
		if (mess->type == SUBSCRIBE && connectedNodes[IDsource-2] == 1){ //If it's a SUBSCRIBE message and the node is properly connected
			my_msg_subscribe_t* mess_subscribe=(my_msg_subscribe_t*)payload;
			int i = 0;
			dbg("radio_rec","Message received at time %s \n", sim_time_string());
			dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
			dbg_clear("radio_pack","\t Source: %hhu \n", IDsource );
			dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
			dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		  	dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess_subscribe->type); /*We display the type of msg*/
		  	dbg_clear("radio_pack", "\t\t Topics: [%hhu %hhu %hhu]\n", mess_subscribe->topic[0],mess_subscribe->topic[1], mess_subscribe->topic[2]); /*We display the topics to subscribe to*/
		  	dbg_clear("radio_pack", "\t\t QOS: [%d %d %d] \n", mess_subscribe->qos[0],mess_subscribe->qos[1],mess_subscribe->qos[2]); /*We display the qos*/
			for(i=0; i<3; i++){ //We update the subscriptions matrix with the information of the SUBSCRIBE message
				if(mess_subscribe->topic[i] == 1){
					subscriptions[IDsource-2][i]=mess_subscribe->qos[i];
				}
			}
		}
		if(mess->type == PUBLISH){ //If it's a publish message
			if(forwarding == 1){ //If the MQTT Broker is already treating a PUBLISH message
				dbg("radio_rec","The MQTT broker is busy, the publish request coming from the node %hhu is discarded\n",IDsource);		
			}else{ //If the Broker is available
				int p = 0;
				my_msg_publish_t* mess_publish=(my_msg_publish_t*)payload;
				valueToForward = mess_publish->value;
				topicToForward = mess_publish->topic;
				sourceToForward = IDsource;
				dbg("radio_rec","Message received at time %s \n", sim_time_string());
				dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
				dbg_clear("radio_pack","\t Source: %hhu \n", IDsource );
				dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
				dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
			  	dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess_publish->type); //We display the type of msg
			  	dbg_clear("radio_pack", "\t\t Topic: %hhu \n", mess_publish->topic); //We display the topic concerned by the publication
			  	dbg_clear("radio_pack", "\t\t QOS: %hhu \n", mess_publish->qos); //We display the qos
			  	dbg_clear("radio_pack", "\t\t Value: %hhu \n", mess_publish->value); //We display the value
			  	dbg_clear("radio_pack", "\t\t Message ID: %hhu \n", mess_publish->msgId); //We display the msgID
				if(mess_publish->msgId != publishedMsgID[IDsource-2]){ //If this message hasn't been received before (this could happen in case the ACK fails because the node would retransmit the same publish message)
					for(p=0; p<MAX_NB_NODES; p++){ //We copy the subscriptions row corresponding to the topic
						nodesToForward[p] = subscriptions[p][topicToForward-1];
					}
					publishedMsgID[IDsource-2]=mess_publish->msgId;
					index=0;
					forwarding=1;
					post sendForward(); //Start the forwarding procedure
				}else{
					dbg("radio_pack","This publish message has already been received but the PUBACK hasn't been received by the node\n");
				}		
			}
		}
	}else { //If a node is receiving a packet
		my_msg_forward_t* mess_forward=(my_msg_forward_t*)payload;
		dbg("radio_rec","Message received at time %s \n", sim_time_string());
		dbg("radio_pack",">>>Pack \n \t Payload length %hhu \n", call Packet.payloadLength( buf ) );
		dbg_clear("radio_pack","\t Source: %hhu \n", IDsource );
		dbg_clear("radio_pack","\t Destination: %hhu \n", call AMPacket.destination( buf ) );
		dbg_clear("radio_pack","\t AM Type: %hhu \n", call AMPacket.type( buf ) );
		dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess_forward->type); //We display the type of msg
		dbg_clear("radio_pack", "\t\t Topic: %hhu \n", mess_forward->topic); //We display the topic concerned by the publication
		dbg_clear("radio_pack", "\t\t QOS: %hhu \n", mess_forward->qos); //We display the qos
		dbg_clear("radio_pack", "\t\t Value: %hhu \n", mess_forward->value); //We display the value
		dbg_clear("radio_pack", "\t\t Initial source: %hhu \n", mess_forward->source); //We display the msgID
	}
    return buf;
  }
  

  //************************* Read interface **********************//
  event void Read.readDone(error_t result, uint16_t data) {
	my_msg_publish_t* mess=(my_msg_publish_t*)(call Packet.getPayload(&packet,sizeof(my_msg_publish_t)));
	if(retransmission == 1){ //If the publish message has been sent previously but the QoS wasn't fulfilled, we retransmit the same data
		mess->value = valueRetrans;
	}else{ //If it is not a retransmission then we read a new random value
		mess->value = data;
		valueRetrans = data;
	}
	mess->type = PUBLISH; //We fill the field type to mention that it is a PUBLISH message
	mess->msgId = messageID;
	if(TOS_NODE_ID == 2 || TOS_NODE_ID == 5){
		mess->topic = TEMPERATURE; //Publish a temperature message
	} else {
		if(TOS_NODE_ID == 4 || TOS_NODE_ID == 7){		
			mess->topic = HUMIDITY; //Publish a humidity message

		} else {
			mess->topic = LUMINOSITY;
		}
	}	
	if(TOS_NODE_ID<5){ //from node 2 to 4	
		mess->qos = QOS_HIGH;
	} else { //from node 5 to 8
		mess->qos = QOS_LOW;

	}   
	dbg("radio_send", "Try to send a publish request to node 1 (MQTT Broker) at time %s \n", sim_time_string());
    	
	if(mess->qos == QOS_HIGH){//If QOS is high
		call PacketAcknowledgements.requestAck( &packet );//We call the method to ask for acknowledgement
	}else{
		call PacketAcknowledgements.noAck( &packet ); //Otherwise we don't ask the acknowledgment for the packet	
	}
	if(call AMSend.send(1,&packet,sizeof(my_msg_publish_t)) == SUCCESS){ //Here we try to send the packet to the MQTT Broker	
	  dbg("radio_send", "Packet passed to lower layer successfully!\n");
	  dbg("radio_pack",">>>Pack\n \t Payload length %hhu \n", call Packet.payloadLength( &packet ) );
	  dbg_clear("radio_pack","\t Source: %hhu \n ", call AMPacket.source( &packet ) );

	  dbg_clear("radio_pack","\t Destination: %hhu \n ", call AMPacket.destination( &packet ) );
	  dbg_clear("radio_pack","\t AM Type: %hhu \n ", call AMPacket.type( &packet ) );
	  dbg_clear("radio_pack", "\t\t Message type: %hhu \n", mess->type); //We display the type of msg
	  dbg_clear("radio_pack", "\t\t Topic: %hhu \n", mess->topic); //We display the topic concerned by the publication
	  dbg_clear("radio_pack", "\t\t QOS: %hhu \n", mess->qos); //We display the qos
	  dbg_clear("radio_pack", "\t\t Value: %hhu \n", mess->value); //We display the value
	  dbg_clear("radio_pack", "\t\t Message ID: %hhu \n", mess->msgId); //We display the msgID
        }
  }
}

