/**
 *  Configuration file for wiring of FakeSensorP module to other common 
 *  components to simulate the behavior of a real sensor
 *
 *  @author Luca Pietro Borsani
 */
 
generic configuration FakeSensorC() {

	provides interface Read<uint16_t>;

} implementation {

	components MainC, RandomC;
	components new FakeSensorP();
	components new TimerMilliC();
	
	//Connects the provided interface
	Read = FakeSensorP;
	
	//Random interface and its initialization	
	FakeSensorP.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;
	
	//Timer interface	
	FakeSensorP.Timer0 -> TimerMilliC;

}
