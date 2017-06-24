/**
 *  IOT - Project
 *  Configuration file for wiring of mqttC module to other common 
 *  components needed for proper functioning
 *
 *  @author Antoine Le Calvez - Mëmëdhe G. Ibrahimi
 */

#include "mqtt.h"

configuration mqttAppC {}

implementation {

  components MainC, mqttC as App;
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new TimerMilliC() as Timer3;
  components new TimerMilliC() as Timer4;
  components new FakeSensorC();

  //Boot interface
  App.Boot -> MainC.Boot;

  //Send and Receive interfaces
  App.Receive -> AMReceiverC;
  App.AMSend -> AMSenderC;

  //Radio Control
  App.SplitControl -> ActiveMessageC;

  //Interfaces to access package fields
  App.AMPacket -> AMSenderC;
  App.Packet -> AMSenderC;
  App.PacketAcknowledgements->ActiveMessageC;

  //Timer interface
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Timer2 -> Timer2;
  App.Timer3 -> Timer3;
  App.Timer4 -> Timer4;

  //Fake Sensor read
  App.Read -> FakeSensorC; /*FakeSensor component, returns a random value*/

}

